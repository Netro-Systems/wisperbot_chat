part of 'models.dart';

/// Agent typing state reported by the latest realtime event.
class WisperBotAgentTyping {
  /// Creates an active typing state with an optional safe display name.
  const WisperBotAgentTyping({this.name});

  /// Backend-supplied agent display name, when available.
  final String? name;
}
