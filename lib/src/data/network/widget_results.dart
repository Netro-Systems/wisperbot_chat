import '../../domain/contracts/session_store.dart';
import '../../domain/models/models.dart';

/// Parsed result of creating or restoring a visitor session.
///
/// This transport-facing aggregate remains internal to the SDK and keeps raw
/// response maps from crossing the data boundary.
final class WidgetSessionResult {
  /// Creates a fully decoded session result.
  WidgetSessionResult({
    required this.session,
    required this.conversationId,
    required this.widget,
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
  });

  /// Secure visitor credentials returned by the backend.
  final WisperBotStoredSession session;

  /// Token-bound conversation identifier returned by the backend.
  final int conversationId;

  /// Backend-authoritative widget configuration.
  final WisperBotWidgetConfig widget;

  /// Initial ordered conversation batch.
  final List<WisperBotMessage> messages;

  /// Current working-hours availability.
  final WisperBotSupportAvailability supportAvailability;

  /// Current human-handoff state.
  final WisperBotHandoffState handoff;
}

/// Parsed result of one user-requested or initialization catch-up page.
final class WidgetRefreshResult {
  WidgetRefreshResult({
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
    required this.agentTyping,
  });

  final List<WisperBotMessage> messages;
  final WisperBotSupportAvailability supportAvailability;
  final WisperBotHandoffState handoff;
  final WisperBotAgentTyping? agentTyping;
}

/// Parsed server confirmation for a visitor send.
final class WidgetSendResult {
  /// Creates a decoded send result.
  WidgetSendResult({required this.message, required this.handoff});

  /// Backend-confirmed visitor message.
  final WisperBotMessage message;

  /// Handoff state returned alongside the send.
  final WisperBotHandoffState handoff;
}
