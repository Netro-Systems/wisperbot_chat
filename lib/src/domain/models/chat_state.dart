part of 'models.dart';

/// Lifecycle phase of a chat controller.
enum WisperBotChatPhase {
  idle,
  initializing,
  awaitingPreChat,
  ready,
  reconnecting,
  expired,
  failure,
  disposed
}

/// Network synchronization state, separate from support availability.
enum WisperBotConnectionState { disconnected, connecting, connected, reconnecting }

/// Working-hours availability reported by the backend.
enum WisperBotSupportAvailability { unknown, available, unavailable }

/// Immutable snapshot emitted by a chat controller.
class WisperBotChatState {
  /// Creates a state snapshot and defensively copies [messages].
  WisperBotChatState({
    required this.phase,
    required List<WisperBotMessage> messages,
    required this.connection,
    required this.widget,
    required this.handoff,
    required this.supportAvailability,
    required this.visitorTyping,
    required this.agentTyping,
    required this.pendingCount,
    this.error,
  }) : messages = List<WisperBotMessage>.unmodifiable(messages);

  /// Creates the initial disconnected state.
  factory WisperBotChatState.initial() => WisperBotChatState(
        phase: WisperBotChatPhase.idle,
        messages: const <WisperBotMessage>[],
        connection: WisperBotConnectionState.disconnected,
        widget: null,
        handoff: const WisperBotHandoffState.unavailable(),
        supportAvailability: WisperBotSupportAvailability.unknown,
        visitorTyping: false,
        agentTyping: null,
        pendingCount: 0,
      );

  /// Session lifecycle phase.
  final WisperBotChatPhase phase;

  /// Ordered, deduplicated messages.
  final List<WisperBotMessage> messages;

  /// Network synchronization status.
  final WisperBotConnectionState connection;

  /// Server widget configuration after initialization.
  final WisperBotWidgetConfig? widget;

  /// Backend-authoritative handoff state.
  final WisperBotHandoffState handoff;

  /// Support working-hours availability.
  final WisperBotSupportAvailability supportAvailability;

  /// Whether the controller last published visitor typing as active.
  final bool visitorTyping;

  /// Current agent typing state, if active.
  final WisperBotAgentTyping? agentTyping;

  /// Number of pending or unconfirmed visitor messages.
  final int pendingCount;

  /// Current recoverable or terminal error.
  final WisperBotException? error;

  /// Returns an updated immutable state snapshot.
  WisperBotChatState copyWith({
    WisperBotChatPhase? phase,
    List<WisperBotMessage>? messages,
    WisperBotConnectionState? connection,
    Object? widget = _notProvided,
    WisperBotHandoffState? handoff,
    WisperBotSupportAvailability? supportAvailability,
    bool? visitorTyping,
    Object? agentTyping = _notProvided,
    int? pendingCount,
    Object? error = _notProvided,
  }) =>
      WisperBotChatState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        widget: identical(widget, _notProvided) ? this.widget : widget as WisperBotWidgetConfig?,
        handoff: handoff ?? this.handoff,
        supportAvailability: supportAvailability ?? this.supportAvailability,
        visitorTyping: visitorTyping ?? this.visitorTyping,
        agentTyping: identical(agentTyping, _notProvided)
            ? this.agentTyping
            : agentTyping as WisperBotAgentTyping?,
        pendingCount: pendingCount ?? this.pendingCount,
        error: identical(error, _notProvided) ? this.error : error as WisperBotException?,
      );
}

const Object _notProvided = Object();
