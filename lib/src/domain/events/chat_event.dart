import '../models/models.dart';

/// Base type for lifecycle and message events emitted by a chat controller.
sealed class WisperBotChatEvent {
  /// Creates a chat event.
  const WisperBotChatEvent();
}

/// Describes why a prebuilt chat presentation was closed.
enum WisperBotChatCloseReason {
  userClosed,
  sessionReset,
  configurationFailure,
}

/// Emitted after a session becomes ready for messaging.
final class WisperBotSessionReady extends WisperBotChatEvent {
  /// Creates a session-ready event.
  const WisperBotSessionReady();
}

/// Emitted when a prebuilt presentation opens.
final class WisperBotChatOpened extends WisperBotChatEvent {
  /// Creates a presentation-opened event.
  const WisperBotChatOpened();
}

/// Emitted when a prebuilt presentation closes.
final class WisperBotChatClosed extends WisperBotChatEvent {
  /// Creates a close event with its [reason].
  const WisperBotChatClosed({required this.reason});

  /// Reason reported by the presentation.
  final WisperBotChatCloseReason reason;
}

/// Emitted after a visitor message is confirmed by the backend.
final class WisperBotMessageSent extends WisperBotChatEvent {
  /// Creates a sent-message event.
  const WisperBotMessageSent({required this.message});

  /// Confirmed visitor message.
  final WisperBotMessage message;
}

/// Emitted for a newly reconciled incoming message.
final class WisperBotMessageReceived extends WisperBotChatEvent {
  /// Creates a received-message event.
  const WisperBotMessageReceived({required this.message});

  /// Newly received message.
  final WisperBotMessage message;
}

/// Emitted when the backend-authoritative handoff state changes.
final class WisperBotHandoffChanged extends WisperBotChatEvent {
  /// Creates a handoff change event.
  const WisperBotHandoffChanged({required this.handoff});

  /// Updated handoff state.
  final WisperBotHandoffState handoff;
}

/// Emitted when network synchronization state changes.
final class WisperBotConnectionChanged extends WisperBotChatEvent {
  /// Creates a connection change event.
  const WisperBotConnectionChanged({required this.connection});

  /// Updated connection state.
  final WisperBotConnectionState connection;
}
