import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/polling_coordinator.dart';

void main() {
  const config = WisperBotPollingConfig(
    visibleInterval: Duration(seconds: 1),
    idleInterval: Duration(seconds: 8),
    failureMaxInterval: Duration(seconds: 30),
  );

  test('enforces minimum foreground interval', () {
    final coordinator = PollingCoordinator(random: Random(1));
    final now = DateTime.utc(2026, 8, 6);

    expect(
      coordinator.nextDelay(
        config: config,
        failures: 0,
        retryAfter: null,
        lastActivity: now,
        now: now,
      ),
      const Duration(seconds: 3),
    );
  });

  test('honors server retry-after and selects idle interval', () {
    final coordinator = PollingCoordinator(random: Random(1));
    final now = DateTime.utc(2026, 8, 6);

    expect(
      coordinator.nextDelay(
        config: config,
        failures: 1,
        retryAfter: const Duration(seconds: 12),
        lastActivity: now,
        now: now,
      ),
      const Duration(seconds: 12),
    );
    expect(
      coordinator.nextDelay(
        config: config,
        failures: 0,
        retryAfter: null,
        lastActivity: now.subtract(const Duration(minutes: 1)),
        now: now,
      ),
      const Duration(seconds: 8),
    );
  });

  test('listener leases and foreground state gate scheduling', () {
    final coordinator = PollingCoordinator(random: Random(1));

    expect(coordinator.hasLease, isFalse);
    expect(coordinator.setStateLease(true), isTrue);
    expect(coordinator.hasLease, isTrue);
    expect(coordinator.setEventLease(true), isFalse);
    expect(coordinator.setStateLease(false), isFalse);
    expect(coordinator.setEventLease(false), isTrue);

    coordinator.updateLifecycle(AppLifecycleState.paused);
    expect(coordinator.isForeground, isFalse);
    coordinator.updateLifecycle(AppLifecycleState.resumed);
    expect(coordinator.isForeground, isTrue);
    coordinator.dispose();
    expect(coordinator.hasLease, isFalse);
  });

  test('dispose cancels a scheduled poll callback', () async {
    final coordinator = PollingCoordinator(random: Random(1));
    var polls = 0;
    coordinator.setStateLease(true);
    coordinator.schedule(
      phase: WisperBotChatPhase.ready,
      config: config,
      failures: 0,
      retryAfter: null,
      lastActivity: DateTime.now(),
      now: DateTime.now(),
      poll: () async => polls++,
    );

    coordinator.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(polls, 0);
  });
}
