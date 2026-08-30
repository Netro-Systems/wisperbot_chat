part of '../view/chat_view.dart';

class _DefaultMediaAdapter implements WisperBotMediaAdapter {
  _DefaultMediaAdapter({ImagePicker? imagePicker, AudioRecorder? recorder})
      : _imagePicker = imagePicker ?? ImagePicker(),
        _recorder = recorder ?? AudioRecorder();

  final ImagePicker _imagePicker;
  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _recordingSubscription;
  Completer<void>? _recordingDone;
  BytesBuilder? _recordingBytes;
  Object? _recordingError;

  static const int _recordingSampleRate = 16000;
  static const int _recordingChannels = 1;

  @override
  Future<WisperBotUpload?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 2048,
      maxHeight: 2048,
      imageQuality: 90,
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final filename = file.name.trim();
    final mimeType = (file.mimeType ?? _imageMimeType(filename)).toLowerCase();
    _validateMedia(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      allowedMimeTypes: const <String>{
        'image/jpeg',
        'image/png',
        'image/webp',
      },
    );
    return WisperBotUpload(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
    );
  }

  /// Opens camera to capture an image.
  Future<WisperBotUpload?> pickCameraImage() => pickImage(source: ImageSource.camera);

  /// Opens gallery to select an image.
  Future<WisperBotUpload?> pickGalleryImage() => pickImage(source: ImageSource.gallery);

  @override
  Future<WisperBotUpload?> pickDocument() async {
    const docTypeGroup = XTypeGroup(
      label: 'documents',
      extensions: <String>[
        'pdf',
        'doc',
        'docx',
        'txt',
        'rtf',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'csv',
        'zip',
        'rar',
        'json',
        'xml',
      ],
    );
    XFile? file;
    try {
      file = await openFile(
        acceptedTypeGroups: const <XTypeGroup>[docTypeGroup],
      );
    } on Object {
      try {
        file = await openFile();
      } on Object {
        return null;
      }
    }
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    final filename = file.name.trim();
    final mimeType = (file.mimeType ?? _documentMimeType(filename)).toLowerCase();
    _validateMedia(
      bytes: bytes,
      filename: filename,
      mimeType: mimeType,
      allowedMimeTypes: const <String>{
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
        'text/plain',
        'text/csv',
        'text/comma-separated-values',
        'application/csv',
        'application/zip',
        'application/x-zip-compressed',
        'application/x-rar-compressed',
        'application/rtf',
        'text/rtf',
        'application/json',
        'text/json',
        'application/xml',
        'text/xml',
        'application/octet-stream',
      },
    );
    return WisperBotUpload(
      bytes: bytes,
      filename: filename,
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
        encoder: AudioEncoder.pcm16bits,
        numChannels: _recordingChannels,
        sampleRate: _recordingSampleRate,
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
    final pcmBytes = _recordingBytes?.takeBytes() ?? Uint8List(0);
    _clearRecordingState();
    if (error != null) throw error;
    if (pcmBytes.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'No audio was captured. Please try again.',
        retryable: true,
      );
    }

    final bytes = _encodePcm16AsWav(
      pcmBytes,
      sampleRate: _recordingSampleRate,
      channels: _recordingChannels,
    );
    _validateMedia(
      bytes: bytes,
      filename: 'voice.wav',
      mimeType: 'audio/wav',
      allowedMimeTypes: const <String>{'audio/wav'},
    );

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

  String _documentMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.pptx')) {
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.rar')) return 'application/x-rar-compressed';
    if (lower.endsWith('.rtf')) return 'application/rtf';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.xml')) return 'application/xml';
    return 'application/octet-stream';
  }

  String _imageMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    throw const WisperBotException(
      code: WisperBotErrorCode.attachmentRejected,
      message: 'Choose a JPG, PNG, or WebP image.',
      retryable: false,
    );
  }

  void _validateMedia({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    required Set<String> allowedMimeTypes,
  }) {
    if (bytes.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'The selected media file is empty.',
        retryable: false,
      );
    }
    if (bytes.length > 10 * 1024 * 1024) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'Choose a media file under 10 MB.',
        retryable: false,
      );
    }
    if (filename.isEmpty || !allowedMimeTypes.contains(mimeType)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'The selected media format is not supported.',
        retryable: false,
      );
    }
  }
}

Uint8List _encodePcm16AsWav(
  Uint8List pcmBytes, {
  required int sampleRate,
  required int channels,
}) {
  const bitsPerSample = 16;
  const headerLength = 44;
  final bytesPerSample = bitsPerSample ~/ 8;
  final byteRate = sampleRate * channels * bytesPerSample;
  final blockAlign = channels * bytesPerSample;
  final wav = Uint8List(headerLength + pcmBytes.length);
  final data = ByteData.sublistView(wav);

  void writeAscii(int offset, String value) {
    for (var index = 0; index < value.length; index++) {
      wav[offset + index] = value.codeUnitAt(index);
    }
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, wav.length - 8, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, pcmBytes.length, Endian.little);
  wav.setRange(headerLength, wav.length, pcmBytes);
  return wav;
}
