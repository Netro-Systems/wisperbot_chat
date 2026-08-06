import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/widget_api.dart';

import '../support/fakes.dart';

void main() {
  group('backend request contract', () {
    test('session sends only documented JSON fields and restoration header',
        () async {
      late http.BaseRequest recorded;
      late Map<String, dynamic> body;
      final client = _RecordingClient((request) async {
        recorded = request;
        body = jsonDecode(await request.finalize().bytesToString())
            as Map<String, dynamic>;
        return _jsonResponse(sessionResponse());
      });
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com/base'),
        httpClient: client,
      );

      await api.startSession(
        widgetKey: 'test-widget',
        user: WisperBotUser(
          externalId: 'customer-1',
          name: 'Jane Doe',
          email: 'jane@example.com',
          avatarUrl: Uri.parse('https://example.com/jane.png'),
          signature: 'signed-hash',
        ),
        storedSession: WisperBotStoredSession(
          visitorId: 'visitor-1',
          token: 'token-1',
          savedAt: DateTime.utc(2026, 8, 1),
        ),
      );

      expect(recorded.method, 'POST');
      expect(recorded.url.path, '/base/widget/v1/session');
      expect(recorded.headers['content-type'], 'application/json');
      expect(recorded.headers['accept'], 'application/json');
      expect(recorded.headers['x-widget-token'], 'token-1');
      _expectNoInventedHeaders(recorded);
      expect(body, <String, dynamic>{
        'key': 'test-widget',
        'visitor_id': 'visitor-1',
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'avatar': 'https://example.com/jane.png',
        'external_id': 'customer-1',
        'user_hash': 'signed-hash',
      });
    });

    test('text, poll, typing, and handoff match backend wire shapes', () async {
      final requests = <http.BaseRequest>[];
      final bodies = <Map<String, dynamic>>[];
      final client = _RecordingClient((request) async {
        requests.add(request);
        if (request is http.Request && request.body.isNotEmpty) {
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        }
        if (request.url.path.endsWith('/messages') &&
            request.method == 'POST') {
          return _jsonResponse(<String, Object?>{
            'message': message(id: 1, role: 'visitor', sentBy: 'human'),
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'bot',
            },
          });
        }
        if (request.url.path.endsWith('/messages')) {
          return _jsonResponse(pollResponse());
        }
        if (request.url.path.endsWith('/handoff')) {
          return _jsonResponse(<String, Object?>{
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'connected',
            },
          });
        }
        return _jsonResponse(<String, Object?>{'ok': true});
      });
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: client,
      );

      await api.sendText(
        widgetKey: 'test-widget',
        token: 'token-1',
        text: 'Hello',
      );
      await api.poll(widgetKey: 'test-widget', token: 'token-1', after: 42);
      await api.setTyping(
        widgetKey: 'test-widget',
        token: 'token-1',
        isTyping: true,
      );
      await api.requestHandoff(widgetKey: 'test-widget', token: 'token-1');

      expect(bodies[0], <String, dynamic>{
        'key': 'test-widget',
        'message': 'Hello',
      });
      expect(requests[1].method, 'GET');
      expect(requests[1].url.queryParameters, <String, String>{
        'key': 'test-widget',
        'after': '42',
      });
      expect(requests[1].headers.containsKey('content-type'), isFalse);
      expect(bodies[1], <String, dynamic>{
        'key': 'test-widget',
        'is_typing': true,
      });
      expect(bodies[2], <String, dynamic>{'key': 'test-widget'});
      for (final request in requests) {
        expect(request.headers['x-widget-token'], 'token-1');
        _expectNoInventedHeaders(request);
      }
    });

    test('media uses multipart fields and maps backend rejection', () async {
      var calls = 0;
      final client = _RecordingClient((request) async {
        calls++;
        expect(request, isA<http.MultipartRequest>());
        final multipart = request as http.MultipartRequest;
        expect(multipart.fields, <String, String>{
          'key': 'test-widget',
          'type': 'image',
          'message': 'A caption',
        });
        expect(multipart.files, hasLength(1));
        expect(multipart.files.single.field, 'attachment');
        expect(multipart.files.single.filename, 'photo.png');
        expect(multipart.headers['accept'], 'application/json');
        expect(multipart.headers['x-widget-token'], 'token-1');
        _expectNoInventedHeaders(multipart);
        if (calls == 1) {
          return _jsonResponse(<String, Object?>{
            'message': <String, Object?>{
              ...message(id: 4, role: 'visitor', type: 'image'),
              'attachment_url': 'https://cdn.example.com/photo.png',
              'filename': 'photo.png',
              'mime_type': 'image/png',
            },
            'handoff': <String, Object?>{
              'enabled': false,
              'eligible': false,
              'status': 'bot',
            },
          });
        }
        return _jsonResponse(
          <String, Object?>{
            'message': 'The attachment field must be an image.',
            'errors': <String, Object?>{
              'attachment': <String>['The attachment is invalid.'],
            },
          },
          status: 422,
        );
      });
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: client,
      );
      final upload = WisperBotUpload(
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        filename: 'photo.png',
        mimeType: 'image/png',
      );

      final sent = await api.sendUpload(
        widgetKey: 'test-widget',
        token: 'token-1',
        upload: upload,
        type: WisperBotMessageType.image,
        caption: ' A caption ',
      );
      expect(sent.message.attachment?.mimeType, 'image/png');

      await expectLater(
        api.sendUpload(
          widgetKey: 'test-widget',
          token: 'token-1',
          upload: upload,
          type: WisperBotMessageType.image,
          caption: 'A caption',
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
  });

  group('backend response contract', () {
    test('preserves every backend sender kind', () async {
      final response = sessionResponse(messages: <Map<String, Object?>>[
        message(id: 1, sentBy: 'bot'),
        message(id: 2, sentBy: 'human'),
        message(id: 3, sentBy: 'automation'),
        message(id: 4, sentBy: 'broadcast'),
      ]);
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((_) async => _jsonResponse(response)),
      );

      final result = await api.startSession(
        widgetKey: 'test-widget',
        user: null,
        storedSession: null,
      );

      expect(
        result.messages.map((item) => item.sentBy),
        <WisperBotSenderKind>[
          WisperBotSenderKind.bot,
          WisperBotSenderKind.human,
          WisperBotSenderKind.automation,
          WisperBotSenderKind.broadcast,
        ],
      );
    });

    test('rejects malformed required message fields', () async {
      final response = sessionResponse(messages: <Map<String, Object?>>[
        <String, Object?>{
          'id': 1,
          'role': 'agent',
          'type': 'text',
          'body': 'Missing timestamp',
        },
      ]);
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((_) async => _jsonResponse(response)),
      );

      await expectLater(
        api.startSession(
          widgetKey: 'test-widget',
          user: null,
          storedSession: null,
        ),
        throwsA(
          isA<WisperBotException>().having(
            (error) => error.code,
            'code',
            WisperBotErrorCode.server,
          ),
        ),
      );
    });

    test('rejects absent authoritative session and poll state', () async {
      final malformedSession = sessionResponse()..remove('handoff');
      final sessionApi = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(malformedSession),
        ),
      );
      await expectLater(
        sessionApi.startSession(
          widgetKey: 'test-widget',
          user: null,
          storedSession: null,
        ),
        throwsA(
          isA<WisperBotException>().having(
            (error) => error.code,
            'code',
            WisperBotErrorCode.server,
          ),
        ),
      );

      final malformedPoll = pollResponse()..remove('agent_typing');
      final pollApi = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(malformedPoll),
        ),
      );
      await expectLater(
        pollApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 0,
        ),
        throwsA(
          isA<WisperBotException>().having(
            (error) => error.code,
            'code',
            WisperBotErrorCode.server,
          ),
        ),
      );
    });

    test('keeps unknown message enums safe and parses poll state', () async {
      final api = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient(
          (_) async => _jsonResponse(<String, Object?>{
            ...pollResponse(),
            'online': false,
            'agent_typing': <String, Object?>{
              'is_typing': true,
              'name': 'Taylor',
            },
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'future_status',
            },
            'messages': <Map<String, Object?>>[
              message(
                id: 9,
                role: 'future_role',
                type: 'future_type',
                sentBy: 'future_sender',
              ),
            ],
            'future_field': 'ignored',
          }),
        ),
      );

      final result = await api.poll(
        widgetKey: 'test-widget',
        token: 'token-1',
        after: 0,
      );

      expect(
        result.supportAvailability,
        WisperBotSupportAvailability.unavailable,
      );
      expect(result.agentTyping, isNotNull);
      expect(result.handoff.status, WisperBotHandoffStatus.unavailable);
      expect(result.messages.single.role, WisperBotMessageRole.unknown);
      expect(result.messages.single.type, WisperBotMessageType.unknown);
      expect(result.messages.single.sentBy, WisperBotSenderKind.unknown);
    });

    test('maps operation-aware HTTP failures and Retry-After', () async {
      Future<WisperBotException> sessionFailure(int status) async {
        final api = WidgetApiClient(
          baseUrl: Uri.parse('https://chat.example.com'),
          httpClient: _RecordingClient(
            (_) async => _jsonResponse(<String, Object?>{}, status: status),
          ),
        );
        try {
          await api.startSession(
            widgetKey: 'test-widget',
            user: null,
            storedSession: null,
          );
        } on WisperBotException catch (error) {
          return error;
        }
        throw StateError('Expected session request to fail.');
      }

      final missingWidget = await sessionFailure(404);
      expect(missingWidget.code, WisperBotErrorCode.configuration);
      expect(missingWidget.retryable, isFalse);

      final forbidden = await sessionFailure(403);
      expect(forbidden.code, WisperBotErrorCode.forbidden);

      final expired = await sessionFailure(401);
      expect(expired.code, WisperBotErrorCode.sessionExpired);
      expect(expired.retryable, isFalse);

      final authenticatedApi = WidgetApiClient(
        baseUrl: Uri.parse('https://chat.example.com'),
        httpClient: _RecordingClient((request) async {
          if (request.url.queryParameters['after'] == '1') {
            return http.StreamedResponse(
              Stream<List<int>>.value(utf8.encode('{}')),
              429,
              headers: <String, String>{
                'content-type': 'application/json',
                'retry-after': '17',
              },
            );
          }
          return _jsonResponse(<String, Object?>{}, status: 404);
        }),
      );

      await expectLater(
        authenticatedApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 0,
        ),
        throwsA(
          isA<WisperBotException>()
              .having(
                (error) => error.code,
                'code',
                WisperBotErrorCode.sessionExpired,
              )
              .having((error) => error.retryable, 'retryable', isTrue),
        ),
      );
      await expectLater(
        authenticatedApi.poll(
          widgetKey: 'test-widget',
          token: 'token-1',
          after: 1,
        ),
        throwsA(
          isA<WisperBotException>()
              .having(
                (error) => error.code,
                'code',
                WisperBotErrorCode.rateLimited,
              )
              .having(
                (error) => error.retryAfter,
                'retryAfter',
                const Duration(seconds: 17),
              ),
        ),
      );
    });
  });
}

void _expectNoInventedHeaders(http.BaseRequest request) {
  final names = request.headers.keys.map((key) => key.toLowerCase()).toSet();
  expect(names, isNot(contains('x-wisperbot-sdk')));
  expect(names, isNot(contains('x-wisperbot-filename-b64')));
  expect(names, isNot(contains('x-wisperbot-caption-b64')));
  expect(names, isNot(contains('origin')));
  expect(names, isNot(contains('referer')));
}

http.StreamedResponse _jsonResponse(
  Object body, {
  int status = 200,
}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
