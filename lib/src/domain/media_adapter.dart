import 'models.dart';

/// Host-supplied bridge for the optional platform UI used by the default
/// composer to choose images and record microphone audio.
///
/// The SDK owns upload and message state. Implementations own platform picker
/// and recorder dependencies, permissions, and temporary resources.
abstract interface class WisperBotMediaAdapter {
  Future<WisperBotUpload?> pickImage();

  Future<void> startAudioRecording();

  Future<WisperBotUpload?> stopAudioRecording();

  Future<void> cancelAudioRecording();
}
