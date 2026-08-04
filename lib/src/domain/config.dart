import 'package:flutter/material.dart';

import 'errors.dart';
import 'media_adapter.dart';

enum WisperBotPresentation { fullScreen, bottomSheet, dialog }

enum WisperBotChatCloseReason {
  userClosed,
  sessionReset,
  configurationFailure,
}

@immutable
class WisperBotChatResult {
  const WisperBotChatResult({required this.reason});

  final WisperBotChatCloseReason reason;
}

@immutable
class WisperBotPollingConfig {
  const WisperBotPollingConfig({
    this.visibleInterval = const Duration(seconds: 3),
    this.idleInterval = const Duration(seconds: 8),
    this.failureMaxInterval = const Duration(seconds: 30),
  });

  final Duration visibleInterval;
  final Duration idleInterval;
  final Duration failureMaxInterval;
}

@immutable
class WisperBotUser {
  const WisperBotUser({
    this.externalId,
    this.name,
    this.email,
    this.avatarUrl,
    this.signature,
  });

  final String? externalId;
  final String? name;
  final String? email;
  final Uri? avatarUrl;
  final String? signature;

  @override
  String toString() =>
      'WisperBotUser(externalId: [redacted], name: [redacted], '
      'email: [redacted], avatarUrl: [redacted], signature: [redacted])';
}

@immutable
class WisperBotThemeData {
  const WisperBotThemeData({
    this.primaryColor,
    this.backgroundColor,
    this.surfaceColor,
    this.visitorBubbleColor,
    this.agentBubbleColor,
    this.onVisitorBubbleColor,
    this.onAgentBubbleColor,
    this.errorColor,
    this.borderRadius,
    this.messageSpacing,
    this.launcherSize,
    this.brightness,
  });

  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? surfaceColor;
  final Color? visitorBubbleColor;
  final Color? agentBubbleColor;
  final Color? onVisitorBubbleColor;
  final Color? onAgentBubbleColor;
  final Color? errorColor;
  final double? borderRadius;
  final double? messageSpacing;
  final double? launcherSize;
  final Brightness? brightness;
}

typedef WisperBotDiagnosticsCallback = void Function(
    WisperBotDiagnosticEvent event);

enum WisperBotDiagnosticKind {
  initialization,
  lifecycle,
  connection,
  poll,
  send,
  capability,
  realtime,
}

@immutable
class WisperBotDiagnosticEvent {
  const WisperBotDiagnosticEvent({
    required this.kind,
    required this.occurredAt,
    this.duration,
    this.httpStatus,
    this.errorCode,
  });

  final WisperBotDiagnosticKind kind;
  final DateTime occurredAt;
  final Duration? duration;
  final int? httpStatus;
  final WisperBotErrorCode? errorCode;
}

@immutable
class WisperBotConfig {
  const WisperBotConfig({
    required this.widgetKey,
    this.apiBaseUrl = 'https://wisperbot.com',
    this.user,
    this.theme,
    this.useApiColors = true,
    this.presentation = WisperBotPresentation.fullScreen,
    this.enableTyping = true,
    this.mediaAdapter,
    this.polling = const WisperBotPollingConfig(),
    this.diagnostics,
  });

  final String widgetKey;
  final String apiBaseUrl;
  final WisperBotUser? user;
  final WisperBotThemeData? theme;
  final bool useApiColors;
  final WisperBotPresentation presentation;
  final bool enableTyping;
  final WisperBotMediaAdapter? mediaAdapter;
  final WisperBotPollingConfig polling;
  final WisperBotDiagnosticsCallback? diagnostics;
}
