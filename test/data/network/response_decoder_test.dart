import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/network/response_decoder.dart';

import '../../support/support.dart';

void main() {
  const decoder = WidgetResponseDecoder();

  test('public widget loader configuration is decoded without evaluation', () {
    final config = sessionResponse()['config'];
    final loader = '''
/* WisperBot Chat Widget loader */
(function () {
  window.__WB_CHAT__ = { key: "test-widget", config: ${jsonEncode(config)} };
  var s = document.createElement('script');
})();
''';

    final result = decoder.configuration(
      http.Response(loader, 200),
      expectedWidgetKey: 'test-widget',
    );

    expect(result.primaryColorHex, '#6258f9');
    expect(result.launcherPosition, WisperBotLauncherPosition.bottomRight);
  });

  test('public activities decode consistently in history and realtime', () {
    final activity =
        message(id: 5, type: 'event', body: 'Rahim joined the chat')
          ..addAll(
              {'kind': 'activity', 'agent_name': 'Rahim', 'sent_by': 'system'});
    final history = decoder
        .session(
          http.Response(jsonEncode(sessionResponse(messages: [activity])), 200),
          preChatCompleted: false,
        )
        .messages
        .single;
    final realtime = decoder.realtimeMessage({'message': activity})!;
    final refresh = decoder
        .refresh(
          http.Response(jsonEncode(pollResponse(messages: [activity])), 200),
        )
        .messages
        .single;
    for (final entry in [history, realtime, refresh]) {
      expect(entry.isActivity, isTrue);
      expect(entry.senderName, 'Rahim');
      expect(entry.body, 'Rahim joined the chat');
      expect(entry.createdAt,
          DateTime.parse(activity['created_at']! as String).toLocal());
      expect(entry.copyWith(localId: 'retained').isActivity, isTrue);
    }
    expect(decoder.realtimeMessage({'message': message(id: 6)})!.isActivity,
        isFalse);
  });

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
    expect(result.widget.starterQuestions, isEmpty);
  });

  test(
      'session decoder parses, sanitizes, orders, and limits starter questions',
      () {
    final oversized = List<String>.filled(81, 'x').join();
    final result = decoder.session(
      http.Response(
        jsonEncode(
          sessionResponse(
            aiEnabled: false,
            starterQuestions: <Map<String, Object?>>[
              <String, Object?>{
                'id': 'sq_first',
                'label': '  First question?  '
              },
              <String, Object?>{'id': 2, 'label': 'Second question?'},
              <String, Object?>{'id': 'bad-empty', 'label': '   '},
              <String, Object?>{'id': 'bad-html', 'label': '<b>Unsafe</b>'},
              <String, Object?>{'id': 'bad-control', 'label': 'Bad\u0007label'},
              <String, Object?>{'id': 'bad-long', 'label': oversized},
              <String, Object?>{'id': 'sq_third', 'label': 'Third question?'},
              <String, Object?>{'id': 'sq_fourth', 'label': 'Fourth question?'},
              <String, Object?>{'id': 'sq_fifth', 'label': 'Fifth question?'},
              <String, Object?>{'id': 'sq_sixth', 'label': 'Sixth question?'},
            ],
          ),
        ),
        200,
      ),
      preChatCompleted: false,
    );

    expect(result.widget.aiEnabled, isFalse);
    expect(
      result.widget.starterQuestions.map((question) => question.id),
      <String>['sq_first', '2', 'sq_third', 'sq_fourth', 'sq_fifth'],
    );
    expect(result.widget.starterQuestions.first.label, 'First question?');
    expect(
      () => result.widget.starterQuestions.add(
        const WisperBotStarterQuestion(id: 'extra', label: 'Extra'),
      ),
      throwsUnsupportedError,
    );
  });

  test('null, invalid, and empty starter-question data decode as empty', () {
    for (final value in <Object?>[null, 'invalid', <Object?>[]]) {
      final response = sessionResponse();
      (response['config']! as Map<String, Object?>)['starter_questions'] =
          value;
      final result = decoder.session(
        http.Response(jsonEncode(response), 200),
        preChatCompleted: false,
      );
      expect(result.widget.starterQuestions, isEmpty);
    }
  });

  test(
      'parses delivery and seen status correctly matching whisperbot-app logic',
      () {
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
      {'delivered_at': '2026-08-30T10:00:00Z'}:
          WisperBotMessageStatus.delivered,
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
          jsonEncode(
              sessionResponse(messages: <Map<String, Object?>>[msgJson])),
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

  test('decodes realtime message status updates defensively', () {
    for (final payload in <Object?>[
      null,
      'invalid',
      {'id': 42},
      {'id': 42, 'status': 1},
      {'id': 'invalid', 'status': 'read'},
      {'id': -1, 'status': 'read'},
      {'id': 1.5, 'status': 'read'},
    ]) {
      expect(decoder.realtimeMessageStatus(payload), isNull);
    }
    for (final status in WisperBotMessageStatus.values) {
      final update = decoder.realtimeMessageStatus({
        'id': 42,
        'status': ' ${status.name.toUpperCase()} ',
      });
      expect(update?.messageId, 42);
      expect(update?.status, status);
    }
    final update = decoder.realtimeMessageStatus(<String, Object?>{
      'id': '42',
      'status': 'seen',
      'conversation_id': 7,
    });

    expect(update?.messageId, 42);
    expect(update?.status, WisperBotMessageStatus.read);
    expect(
      decoder.realtimeMessageStatus(<String, Object?>{
        'id': 42,
        'status': 'unknown',
      }),
      isNull,
    );
    expect(
      decoder.realtimeMessageStatus(<String, Object?>{
        'id': 0,
        'status': 'read',
      }),
      isNull,
    );
  });

  test('malformed responses become typed errors without leaking content', () {
    const secret = 'private-message-body';

    expect(
      () => decoder.session(
        http.Response('{"secret":"$secret"}', 200),
        preChatCompleted: false,
      ),
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
