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

  test('multipart upload preserves documented fields and attachment name', () {
    final request = encoder.uploadRequest(
      endpoint: Uri.parse('https://chat.example.test/widget/v1/messages'),
      headers: const <String, String>{'X-Widget-Token': 'token'},
      widgetKey: 'widget-key',
      upload: WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'photo.png',
        mimeType: 'image/png',
      ),
      type: WisperBotMessageType.image,
      caption: '  Caption  ',
    );

    expect(request.fields, <String, String>{
      'key': 'widget-key',
      'type': 'image',
      'message': 'Caption',
    });
    expect(request.files.single.field, 'attachment');
    expect(request.files.single.filename, 'photo.png');
  });

  test('empty attachments fail before transport execution', () {
    expect(
      () => encoder.uploadRequest(
        endpoint: Uri.parse('https://chat.example.test/widget/v1/messages'),
        headers: const <String, String>{},
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
}
