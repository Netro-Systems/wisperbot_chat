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

  test('parses delivery and seen status correctly matching whisperbot-app logic', () {
    final statusCases = <Map<String, Object?>, WisperBotMessageStatus>{
      {'delivery_status': 'read'}: WisperBotMessageStatus.read,
      {'status': 'seen'}: WisperBotMessageStatus.read,
      {'read_at': '2026-08-30T10:00:00Z'}: WisperBotMessageStatus.read,
      {'is_read': true}: WisperBotMessageStatus.read,
      {'seen': true}: WisperBotMessageStatus.read,
      {'is_seen': true}: WisperBotMessageStatus.read,
      {'state': 'viewed'}: WisperBotMessageStatus.read,
      {'message_status': 'opened'}: WisperBotMessageStatus.read,
      {'delivery_status': 'delivered'}: WisperBotMessageStatus.delivered,
      {'delivered_at': '2026-08-30T10:00:00Z'}: WisperBotMessageStatus.delivered,
      {'is_delivered': true}: WisperBotMessageStatus.delivered,
      {'delivered': true}: WisperBotMessageStatus.delivered,
      {'status': 'received'}: WisperBotMessageStatus.delivered,
      {'status': 'pending'}: WisperBotMessageStatus.pending,
      {'status': 'sending'}: WisperBotMessageStatus.pending,
      {'status': 'failed'}: WisperBotMessageStatus.failed,
      {'status': 'error'}: WisperBotMessageStatus.failed,
      {'status': 'sent'}: WisperBotMessageStatus.sent,
    };

    var id = 10;
    for (final entry in statusCases.entries) {
      id++;
      final msgJson = message(id: id, body: 'Msg $id');
      msgJson.addAll(entry.key);

      final result = decoder.session(
        http.Response(
          jsonEncode(sessionResponse(messages: <Map<String, Object?>>[msgJson])),
          200,
        ),
        preChatCompleted: false,
      );

      final parsed = result.messages.single;
      expect(
        parsed.status,
        entry.value,
        reason: 'Failed for ${entry.key}',
      );
      if (entry.value == WisperBotMessageStatus.read) {
        expect(parsed.isSeen, isTrue);
        expect(parsed.isRead, isTrue);
        expect(parsed.isDelivered, isTrue);
      } else if (entry.value == WisperBotMessageStatus.delivered) {
        expect(parsed.isSeen, isFalse);
        expect(parsed.isDelivered, isTrue);
      }
    }
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
