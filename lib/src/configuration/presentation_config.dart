part of 'wisperbot_config.dart';

/// Supported modal presentation styles for [WisperBotChat.open].
enum WisperBotPresentation { fullScreen, bottomSheet, dialog }

/// Result returned when a prebuilt chat presentation closes.
@immutable
class WisperBotChatResult {
  /// Creates a result with the authoritative close [reason].
  const WisperBotChatResult({required this.reason});

  /// Reason the presentation closed.
  final WisperBotChatCloseReason reason;
}
