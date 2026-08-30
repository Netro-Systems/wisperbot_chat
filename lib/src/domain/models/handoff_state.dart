part of 'models.dart';

/// Current human-support handoff state reported by the backend.
enum WisperBotHandoffStatus { unavailable, eligible, requesting, connected, failed }

/// Immutable handoff state exposed by the controller.
class WisperBotHandoffState {
  /// Creates a handoff state with an optional safe [error].
  const WisperBotHandoffState({required this.status, this.error});

  /// Creates the default state when handoff is not available.
  const WisperBotHandoffState.unavailable()
      : status = WisperBotHandoffStatus.unavailable,
        error = null;

  /// Backend-authoritative handoff status.
  final WisperBotHandoffStatus status;

  /// Recoverable failure associated with a handoff request.
  final WisperBotException? error;
}
