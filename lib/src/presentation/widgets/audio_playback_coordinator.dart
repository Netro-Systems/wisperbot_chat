part of '../view/chat_view.dart';

/// Keeps voice-message playback focused on one active player at a time.
class _AudioPlaybackCoordinator {
  _AudioPlaybackCoordinator._();

  static AudioPlayer? _activePlayer;

  static Future<void> play(AudioPlayer player) async {
    final active = _activePlayer;
    if (active != null && active != player) {
      await active.pause();
    }
    _activePlayer = player;
    await player.play();
  }

  static Future<void> pause(AudioPlayer player) async {
    await player.pause();
    if (_activePlayer == player) {
      _activePlayer = null;
    }
  }

  static void clear(AudioPlayer player) {
    if (_activePlayer == player) {
      _activePlayer = null;
    }
  }
}
