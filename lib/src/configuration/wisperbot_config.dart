library;

import 'package:flutter/material.dart';

import '../domain/contracts/media_adapter.dart';
import '../domain/contracts/session_store.dart';
import '../domain/errors/wisperbot_exception.dart';
import '../domain/events/chat_event.dart';

part '../diagnostics/diagnostic_event.dart';
part 'presentation_config.dart';
part 'theme_data.dart';

/// Internal immutable options used to compose a WisperBot runtime.
///
/// The [widgetKey] is the public Mobile SDK key from Widget Integrations. It is
/// not a secret. Visitor identity is supplied to the runtime separately.
@immutable
class WisperBotConfig {
  /// Creates package configuration for one WisperBot widget.
  const WisperBotConfig({
    required this.widgetKey,
    this.apiBaseUrl = 'https://wisperbot.com',
    this.theme,
    this.useApiColors = true,
    this.lightStatusBarIcons = false,
    this.presentation = WisperBotPresentation.fullScreen,
    this.enableTyping = true,
    this.mediaAdapter,
    this.diagnostics,
    this.oneSignalAppId,
    this.enableOneSignal = true,
    this.requireNotificationPermission = true,
    this.registerVisitorOnAppLaunch = true,
    this.sessionStore,
  });

  /// Public Mobile SDK widget key issued by WisperBot.
  final String widgetKey;

  /// API origin used for widget requests.
  final String apiBaseUrl;

  /// Host presentation overrides for the prebuilt UI.
  final WisperBotThemeData? theme;

  /// Whether server-provided colors participate in theme resolution.
  final bool useApiColors;

  /// Whether full-screen chat uses light (white) status-bar icons and text.
  ///
  /// Enable this for dark or strongly colored chat headers. This setting does
  /// not affect bottom-sheet or dialog presentations.
  final bool lightStatusBarIcons;

  /// Default presentation used by [WisperBotChat.open].
  final WisperBotPresentation presentation;

  /// Whether the controller may publish throttled visitor typing updates.
  final bool enableTyping;

  /// Optional override for built-in image/document picking and audio recording.
  /// When omitted, the prebuilt composer uses the SDK's default media adapter.
  final WisperBotMediaAdapter? mediaAdapter;

  /// Optional receiver for redacted operational diagnostics.
  final WisperBotDiagnosticsCallback? diagnostics;

  /// Optional OneSignal App ID used for push notifications.
  final String? oneSignalAppId;

  /// Whether OneSignal push notification device registration is enabled.
  final bool enableOneSignal;

  /// Requires notification permission before chat starts. Requires OneSignal
  /// to be enabled with an app ID on Android or iOS.
  final bool requireNotificationPermission;

  /// Whether the SDK registers visitor presence when the app launches.
  ///
  /// Opening chat still creates the visitor session required by the chat API
  /// when this is disabled.
  final bool registerVisitorOnAppLaunch;

  /// Optional custom session credential store.
  final WisperBotSessionStore? sessionStore;
}
