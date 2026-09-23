import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'audio_file_format.dart';

/// A native playback file, or a data URI on web, owned by one player.
class PreparedAudioSource {
  PreparedAudioSource._(this.source, this._directory);

  final AudioSource source;
  final Directory? _directory;

  static Future<PreparedAudioSource> create(
    Uint8List bytes, {
    required String contentType,
  }) async {
    if (bytes.isEmpty) throw const FormatException('Empty audio');
    if (kIsWeb) {
      return PreparedAudioSource._(
        AudioSource.uri(Uri.dataFromBytes(bytes, mimeType: contentType)),
        null,
      );
    }
    final directory =
        await Directory.systemTemp.createTemp('wisperbot_chat_audio_');
    try {
      final extension =
          audioFileExtension(bytes, filename: '', contentType: contentType);
      final file = await File('${directory.path}/audio.$extension')
          .writeAsBytes(bytes, flush: true);
      return PreparedAudioSource._(AudioSource.uri(file.uri), directory);
    } on Object {
      await directory.delete(recursive: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    final directory = _directory;
    if (directory != null && await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
