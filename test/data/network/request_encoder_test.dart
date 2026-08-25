import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/network/request_encoder.dart';

void main() {
  const encoder = WidgetRequestEncoder();

  test('session body contains restoration and verified identity fields', () {
    final body = encoder.sessionBody(
      widgetKey: 'widget-key',
      user: const WisperBotUser(
        name: 'Visitor',
        email: 'visitor@example.test',
        externalId: 'customer-1',
        signature: 'server-generated-signature',
      ),
      storedSession: WisperBotStoredSession(
        visitorId: 'visitor-1',
        token: 'secret-token',
        savedAt: DateTime.utc(2026),
      ),
    );

    expect(body, <String, Object>{
      'key': 'widget-key',
      'visitor_id': 'visitor-1',
      'name': 'Visitor',
      'email': 'visitor@example.test',
      'external_id': 'customer-1',
      'user_hash': 'server-generated-signature',
    });
  });

  test('session body includes device_id and onesignal_id when provided', () {
    final body = encoder.sessionBody(
      widgetKey: 'widget-key',
      user: const WisperBotUser(
        name: 'Visitor',
        email: 'visitor@example.test',
      ),
      storedSession: null,
      deviceId: 'onesignal-sub-id-123',
    );

    expect(body, <String, Object>{
      'key': 'widget-key',
      'name': 'Visitor',
      'email': 'visitor@example.test',
      'device_id': 'onesignal-sub-id-123',
      'onesignal_id': 'onesignal-sub-id-123',
      'push': <String, Object>{
        'token': 'onesignal-sub-id-123',
      },
    });
  });

  test('multipart upload preserves documented fields and attachment name', () {
    final fields = encoder.uploadFields(
      widgetKey: 'widget-key',
      upload: WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      type: WisperBotMessageType.image,
      caption: '  Caption  ',
    );

    expect(fields, <String, String>{
      'key': 'widget-key',
      'type': 'image',
      'message': 'Caption',
    });
  });

  test('empty attachments fail before transport execution', () {
    expect(
      () => encoder.uploadFields(
        widgetKey: 'widget-key',
        upload: WisperBotUpload(
          bytes: Uint8List(0),
          filename: 'empty.png',
          mimeType: 'image/png',
        ),
        type: WisperBotMessageType.image,
        caption: null,
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.attachmentRejected,
        ),
      ),
    );
  });

  test('multipart upload includes an empty browser-compatible caption', () {
    final fields = encoder.uploadFields(
      widgetKey: 'widget-key',
      upload: WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      type: WisperBotMessageType.image,
      caption: null,
    );

    expect(fields['message'], isEmpty);
  });

  test('rejects oversized attachments and captions before transport', () {
    expect(
      () => encoder.uploadFields(
        widgetKey: 'widget-key',
        upload: WisperBotUpload(
          bytes: Uint8List(10 * 1024 * 1024 + 1),
          filename: 'large.png',
          mimeType: 'image/png',
        ),
        type: WisperBotMessageType.image,
        caption: null,
      ),
      throwsA(isA<WisperBotException>()),
    );
    expect(
      () => encoder.uploadFields(
        widgetKey: 'widget-key',
        upload: WisperBotUpload(
          bytes: Uint8List.fromList(<int>[1]),
          filename: 'photo.png',
          mimeType: 'image/png',
        ),
        type: WisperBotMessageType.image,
        caption: 'x' * 4001,
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.validation,
        ),
      ),
    );
  });

  test('requires supported matching media extensions and MIME types', () {
    for (final upload in <WisperBotUpload>[
      WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'photo.gif',
        mimeType: 'image/gif',
      ),
      WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'photo.png',
        mimeType: 'image/jpeg',
      ),
    ]) {
      expect(
        () => encoder.uploadFields(
          widgetKey: 'widget-key',
          upload: upload,
          type: WisperBotMessageType.image,
          caption: null,
        ),
        throwsA(
          isA<WisperBotException>().having(
            (error) => error.code,
            'code',
            WisperBotErrorCode.attachmentRejected,
          ),
        ),
      );
    }

    final fields = encoder.uploadFields(
      widgetKey: 'widget-key',
      upload: WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1]),
        filename: 'voice.m4a',
        mimeType: 'audio/mp4',
      ),
      type: WisperBotMessageType.audio,
      caption: null,
    );
    expect(fields['type'], 'audio');
  });

  test('accepts every supported website image format', () {
    for (final format in <(String, String)>[
      ('photo.jpg', 'image/jpeg'),
      ('photo.jpeg', 'image/jpeg'),
      ('photo.png', 'image/png'),
      ('photo.webp', 'image/webp'),
    ]) {
      final fields = encoder.uploadFields(
        widgetKey: 'widget-key',
        upload: WisperBotUpload(
          bytes: Uint8List.fromList(<int>[1]),
          filename: format.$1,
          mimeType: format.$2,
        ),
        type: WisperBotMessageType.image,
        caption: null,
      );
      expect(fields['type'], 'image');
      expect(fields['message'], isEmpty);
    }
  });
}
