part of 'widget_api_contract_test.dart';

void _registerRequestContractTests() {
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
      final api = _remoteDataSource(
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
      final api = _remoteDataSource(
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
        expect(multipart.files.single.contentType.toString(), 'image/png');
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
      final api = _remoteDataSource(
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
          isA<WisperBotException>()
              .having(
                (error) => error.code,
                'code',
                WisperBotErrorCode.attachmentRejected,
              )
              .having(
                (error) => error.message,
                'message',
                'The attachment is invalid.',
              ),
        ),
      );
    });
  });
}
