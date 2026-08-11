import '../../domain/models/models.dart';

/// Owns the current immutable controller snapshot.
///
/// Side effects remain in the controller; this type gives state ownership one
/// explicit seam for future transition validation without changing public API.
final class ChatStateMachine {
  WisperBotChatState _state = WisperBotChatState.initial();

  WisperBotChatState get state => _state;

  void replace(WisperBotChatState next) {
    _state = next;
  }
}
