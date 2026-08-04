import 'dart:async';
import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

class ExampleMediaAdapter implements WisperBotMediaAdapter {
  ExampleMediaAdapter({ImagePicker? imagePicker, AudioRecorder? recorder})
      : _imagePicker = imagePicker ?? ImagePicker(),
        _recorder = recorder ?? AudioRecorder();

  final ImagePicker _imagePicker;
  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _recordingSubscription;
  Completer<void>? _recordingDone;
  BytesBuilder? _recordingBytes;
  Object? _recordingError;

  @override
  Future<WisperBotUpload?> pickImage() async {
    final file = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final mimeType = file.mimeType ?? _imageMimeType(file.name);
    return WisperBotUpload(
      bytes: bytes,
      filename: file.name,
      mimeType: mimeType,
    );
  }

  @override
  Future<void> startAudioRecording() async {
    if (_recordingSubscription != null) {
      throw StateError('An audio recording is already active.');
    }
    if (!await _recorder.hasPermission()) {
      throw const WisperBotException(
        code: WisperBotErrorCode.forbidden,
        message: 'Microphone access was not granted.',
        retryable: false,
      );
    }

    _recordingBytes = BytesBuilder(copy: false);
    _recordingDone = Completer<void>();
    _recordingError = null;
    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      ),
    );
    _recordingSubscription = stream.listen(
      _recordingBytes!.add,
      onError: (Object error, StackTrace stackTrace) {
        _recordingError = error;
        if (!(_recordingDone?.isCompleted ?? true)) {
          _recordingDone!.complete();
        }
      },
      onDone: () {
        if (!(_recordingDone?.isCompleted ?? true)) {
          _recordingDone!.complete();
        }
      },
    );
  }

  @override
  Future<WisperBotUpload?> stopAudioRecording() async {
    if (_recordingSubscription == null) return null;
    await _recorder.stop();
    await _recordingDone?.future.timeout(const Duration(seconds: 2));
    await _recordingSubscription?.cancel();

    final error = _recordingError;
    final bytes = _recordingBytes?.takeBytes() ?? Uint8List(0);
    _clearRecordingState();
    if (error != null) throw error;
    if (bytes.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'No audio was captured. Please try again.',
        retryable: true,
      );
    }

    return WisperBotUpload(
      bytes: bytes,
      filename: 'voice-${DateTime.now().millisecondsSinceEpoch}.wav',
      mimeType: 'audio/wav',
    );
  }

  @override
  Future<void> cancelAudioRecording() async {
    if (_recordingSubscription == null) return;
    await _recorder.cancel();
    await _recordingSubscription?.cancel();
    _clearRecordingState();
  }

  Future<void> dispose() async {
    await cancelAudioRecording();
    await _recorder.dispose();
  }

  void _clearRecordingState() {
    _recordingSubscription = null;
    _recordingDone = null;
    _recordingBytes = null;
    _recordingError = null;
  }

  String _imageMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
