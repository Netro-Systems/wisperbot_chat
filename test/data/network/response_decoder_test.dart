import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/network/response_decoder.dart';

import '../../support/support.dart';

void main() {
  const decoder = WidgetResponseDecoder();

  test('session decoder ignores unknown fields and maps known values', () {
    final result = decoder.session(
      http.Response(
        jsonEncode(
          sessionResponse(messages: <Map<String, Object?>>[
            message(id: 4, body: 'Welcome'),
          ]),
        ),
        200,
      ),
      preChatCompleted: false,
    );

    expect(result.session.visitorId, 'visitor-1');
    expect(result.messages.single.serverId, 4);
    expect(result.widget.title, 'Test support');
  });

  test('malformed responses become typed errors without leaking content', () {
    const secret = 'private-message-body';

    expect(
      () => decoder.poll(http.Response('{"secret":"$secret"}', 200)),
      throwsA(
        isA<WisperBotException>()
            .having((error) => error.code, 'code', WisperBotErrorCode.server)
            .having(
              (error) => error.toString(),
              'redacted description',
              isNot(contains(secret)),
            ),
      ),
    );
  });
}
