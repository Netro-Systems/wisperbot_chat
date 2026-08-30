import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../configuration/wisperbot_config.dart';
import '../../domain/models/models.dart';

/// Owns foreground polling timers, listener leases, backoff, and typing expiry.
///
/// A controller supplies state and callbacks, while this coordinator decides
/// whether synchronization is currently permitted and when it should run.
final class PollingCoordinator {
  /// Creates a coordinator with injectable jitter for deterministic tests.
  PollingCoordinator({Random? random}) : _random = random ?? Random.secure();

  static const Duration _agentTypingLifetime = Duration(seconds: 6);

  final Random _random;
  Timer? _pollTimer;
  Timer? _agentTypingTimer;
  bool _stateLease = false;
  bool _eventLease = false;
  bool _foreground = true;
  bool _disposed = false;

  /// Whether at least one state or event listener needs synchronization.
  bool get hasLease => _stateLease || _eventLease;

  /// Whether the host application is currently foregrounded.
  bool get isForeground => _foreground;

  /// Updates the state-stream lease and reports whether demand changed.
  bool setStateLease(bool active) {
    final before = hasLease;
    _stateLease = active;
    return before != hasLease;
  }

  /// Updates the event-stream lease and reports whether demand changed.
  bool setEventLease(bool active) {
    final before = hasLease;
    _eventLease = active;
    return before != hasLease;
  }

  /// Applies an application lifecycle transition.
  ///
  /// Polling is cancelled immediately outside the foreground. The caller
  /// decides whether a resume requires an immediate reconciliation.
  void updateLifecycle(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) cancelPoll();
  }

  /// Schedules the next poll when lifecycle, demand, and phase permit it.
  void schedule({
    required WisperBotChatPhase phase,
    required WisperBotPollingConfig config,
    required int failures,
    required Duration? retryAfter,
    required DateTime lastActivity,
    required DateTime now,
    required Future<void> Function() poll,
  }) {
    cancelPoll();
    if (_disposed ||
        !_foreground ||
        !hasLease ||
        (phase != WisperBotChatPhase.ready && phase != WisperBotChatPhase.reconnecting)) {
      return;
    }
    final duration = nextDelay(
      config: config,
      failures: failures,
      retryAfter: retryAfter,
      lastActivity: lastActivity,
      now: now,
    );
    _pollTimer = Timer(duration, () => unawaited(poll()));
  }

  /// Cancels a scheduled poll without changing listener demand.
  void cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Renews or clears the bounded lifetime of backend typing state.
  void updateAgentTyping({
    required bool active,
    required void Function() onExpired,
  }) {
    _agentTypingTimer?.cancel();
    _agentTypingTimer = null;
    if (!active || _disposed) return;
    _agentTypingTimer = Timer(_agentTypingLifetime, onExpired);
  }

  /// Computes the next bounded foreground polling delay.
  Duration nextDelay({
    required WisperBotPollingConfig config,
    required int failures,
    required Duration? retryAfter,
    required DateTime lastActivity,
    required DateTime now,
  }) {
    const minimum = Duration(seconds: 3);
    if (failures > 0) {
      if (retryAfter != null) {
        return retryAfter < minimum ? minimum : retryAfter;
      }
      final seconds = min(3 * pow(2, min(failures, 4)).toInt(), 30);
      final jitter = 0.85 + _random.nextDouble() * 0.3;
      final backoff = Duration(milliseconds: (seconds * 1000 * jitter).round());
      final bounded = backoff > config.failureMaxInterval ? config.failureMaxInterval : backoff;
      return bounded < minimum ? minimum : bounded;
    }
    final configured = now.difference(lastActivity) > const Duration(seconds: 30)
        ? config.idleInterval
        : config.visibleInterval;
    return configured < minimum ? minimum : configured;
  }

  /// Cancels every owned timer and permanently disables scheduling.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelPoll();
    _agentTypingTimer?.cancel();
    _agentTypingTimer = null;
    _stateLease = false;
    _eventLease = false;
  }
}
