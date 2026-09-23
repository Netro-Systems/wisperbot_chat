import 'dart:io';
import 'dart:typed_data';

import 'package:wisperbot_chat/src/presentation/media/audio_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  for (final entry in {
    'm4a': [0, 0, 0, 24, ...'ftypM4A '.codeUnits],
    'wav': [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WAVE'.codeUnits],
    'mp3': 'ID3'.codeUnits,
  }.entries) {
    test(
        'native ${entry.key} uses real format despite incorrect MIME, then cleans up',
        () async {
      final bytes = Uint8List.fromList(entry.value);
      final prepared =
          await PreparedAudioSource.create(bytes, contentType: 'audio/ogg');
      addTearDown(prepared.dispose);
      final uri = (prepared.source as UriAudioSource).uri;
      expect(uri.scheme, 'file');
      expect(uri.path, endsWith('.${entry.key}'));
      final file = File.fromUri(uri);
      expect(await file.readAsBytes(), bytes);
      await prepared.dispose();
      expect(await file.parent.exists(), isFalse);
    });
  }

  test('empty audio is rejected', () async {
    await expectLater(
      PreparedAudioSource.create(Uint8List(0), contentType: 'audio/wav'),
      throwsFormatException,
    );
  });
}
