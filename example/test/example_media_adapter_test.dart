import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat_example/src/example_media_adapter.dart';

void main() {
  test('PCM16 recording bytes are wrapped in a valid mono WAV container', () {
    final pcm = Uint8List.fromList(<int>[0, 0, 255, 127, 0, 128]);

    final wav = encodePcm16AsWav(pcm, sampleRate: 16000, channels: 1);
    final header = ByteData.sublistView(wav);

    expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), wav.length - 8);
    expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
    expect(ascii.decode(wav.sublist(12, 16)), 'fmt ');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(32, Endian.little), 2);
    expect(header.getUint16(34, Endian.little), 16);
    expect(ascii.decode(wav.sublist(36, 40)), 'data');
    expect(header.getUint32(40, Endian.little), pcm.length);
    expect(wav.sublist(44), pcm);
  });
}
