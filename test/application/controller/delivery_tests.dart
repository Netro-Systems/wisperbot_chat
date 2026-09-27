part of 'chat_controller_test.dart';

void registerDeliveryTests(WisperBotConfig config) {
  test('realtime answer never appears before its pending visitor question',
      () async {
    final connector = _FakeWidgetRealtimeConnector();
    final postStarted = Completer<void>();
    final releasePost = Completer<http.Response>();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
          200,
        );
      }
      if (request.url.path.endsWith('/typing')) {
        return http.Response('{"ok":true}', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        postStarted.complete();
        return releasePost.future;
      }
      if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
        return http.Response(jsonEncode(pollResponse()), 200);
      }
      if (request.url.path.endsWith('/read')) {
        return http.Response('{"ok":true}', 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
      realtimeConnector: connector,
    );
    final controller = WisperBotChatController(client: client);
    final statesSub = controller.states.listen((_) {});

    await controller.initialize();
    final send = controller.sendText('How can I get eSIM?');
    await postStarted.future;
    connector.emitMessageCreated(<String, Object?>{
      'message': message(id: 2, body: 'Choose a package.'),
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.messages, hasLength(1));
    expect(controller.state.messages.single.role, WisperBotMessageRole.visitor);
    expect(
      controller.state.messages.single.status,
      WisperBotMessageStatus.pending,
    );

    releasePost.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 1,
            role: 'visitor',
            body: 'How can I get eSIM?',
            sentBy: 'human',
          ),
          'handoff': <String, Object?>{
            'enabled': true,
            'eligible': false,
            'status': 'bot',
          },
        }),
        200,
      ),
    );
    await send;
    await Future<void>.delayed(Duration.zero);

    expect(
      controller.state.messages.map((item) => item.serverId),
      orderedEquals(<int?>[1, 2]),
    );
    expect(controller.state.messages.first.status, WisperBotMessageStatus.read);

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('successful text send polls immediately and deduplicates realtime reply',
      () async {
    final connector = _FakeWidgetRealtimeConnector();
    final pollStarted = Completer<void>();
    final releasePoll = Completer<http.Response>();
    var pollCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
          200,
        );
      }
      if (request.url.path.endsWith('/typing')) {
        return http.Response('{"ok":true}', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        return http.Response(
          jsonEncode(<String, Object?>{
            'message': message(
              id: 1,
              role: 'visitor',
              body: 'What are your opening hours?',
              sentBy: 'human',
            ),
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'bot',
            },
          }),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
        pollCalls++;
        expect(request.url.queryParameters['after'], '1');
        pollStarted.complete();
        return releasePoll.future;
      }
      if (request.url.path.endsWith('/read')) {
        return http.Response('{"ok":true}', 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
      realtimeConnector: connector,
    );
    final controller = WisperBotChatController(client: client);
    final statesSub = controller.states.listen((_) {});

    await controller.initialize();
    await controller.sendText('What are your opening hours?');
    await pollStarted.future;
    final reply = message(id: 2, body: 'Monday through Friday.');
    connector.emitMessageCreated(<String, Object?>{'message': reply});
    releasePoll.complete(
      http.Response(jsonEncode(pollResponse(messages: [reply])), 200),
    );
    await Future<void>.delayed(Duration.zero);

    expect(pollCalls, 1);
    expect(
      controller.state.messages.where((item) => item.serverId == 2),
      hasLength(1),
    );

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('manual refresh merges messages and availability once', () async {
    var refreshCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(
            sessionResponse(messages: <Map<String, Object?>>[
              message(id: 10, body: 'Initial'),
            ]),
          ),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
        refreshCalls++;
        expect(request.url.queryParameters['after'], '10');
        return http.Response(
          jsonEncode(
            pollResponse(
              online: false,
              messages: <Map<String, Object?>>[
                message(id: 11, body: 'Refreshed'),
              ],
            ),
          ),
          200,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await controller.refresh();

    expect(refreshCalls, 1);
    expect(
      controller.state.messages.map((item) => item.serverId),
      <int?>[10, 11],
    );
    expect(
      controller.state.supportAvailability,
      WisperBotSupportAvailability.unavailable,
    );

    await controller.dispose();
    await client.close();
  });

  test('restores only with the securely stored visitor id and token', () async {
    final store = MemorySessionStore();
    final namespace = sessionNamespace(config: config, user: null);
    store.values[namespace] = WisperBotStoredSession(
      visitorId: 'stored-visitor',
      token: 'stored-token',
      savedAt: DateTime.utc(2026, 8, 1),
    );
    late Map<String, dynamic> requestBody;
    final httpClient = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.headers['X-Widget-Token'], 'stored-token');
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();

    expect(requestBody['visitor_id'], 'stored-visitor');
    expect(store.reads, <String>[namespace]);

    await controller.dispose();
    await client.close();
  });

  test('realtime messages are ordered and deduplicated by server id', () async {
    final store = MemorySessionStore();
    final connector = _FakeWidgetRealtimeConnector();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(
            sessionResponse(
              realtimeKey: 'pusher-key',
              messages: <Map<String, Object?>>[
                message(id: 10, body: 'Initial'),
              ],
            ),
          ),
          200,
        );
      }
      if (request.method == 'POST') {
        return http.Response(
          jsonEncode(<String, Object?>{
            'message': message(
              id: 12,
              role: 'visitor',
              body: 'My message',
              sentBy: 'human',
            ),
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': true,
              'status': 'bot',
            },
          }),
          200,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
      realtimeConnector: connector,
    );
    final controller = WisperBotChatController(client: client);
    final statesSub = controller.states.listen((_) {});

    await controller.initialize();
    final sent = await controller.sendText('My message');
    connector.emitMessageCreated(<String, Object?>{
      'message': message(id: 11, body: 'Reply between IDs'),
    });
    connector.emitMessageCreated(<String, Object?>{
      'message': message(
        id: 12,
        role: 'visitor',
        body: 'My message',
        sentBy: 'human',
      ),
    });

    expect(
      controller.state.messages.map((item) => item.serverId),
      <int?>[10, 11, 12],
    );
    expect(controller.state.messages.last.localId, sent.localId);
    expect(
      controller.state.messages.last.sentBy,
      WisperBotSenderKind.visitor,
    );

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('realtime defers new messages while a send is still in flight',
      () async {
    final sendStarted = Completer<void>();
    final releaseSend = Completer<void>();
    final connector = _FakeWidgetRealtimeConnector();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
          200,
        );
      }
      if (request.url.path.endsWith('/typing')) {
        return http.Response('{"ok":true}', 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        sendStarted.complete();
        await releaseSend.future;
        return http.Response(
          jsonEncode(<String, Object?>{
            'message': message(
              id: 12,
              role: 'visitor',
              body: 'My message',
              sentBy: 'human',
            ),
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': true,
              'status': 'bot',
            },
          }),
          200,
        );
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
      realtimeConnector: connector,
    );
    final controller = WisperBotChatController(client: client);
    final statesSub = controller.states.listen((_) {});

    await controller.initialize();
    final send = controller.sendText('My message');
    await sendStarted.future;
    for (final eventMessage in <Map<String, Object?>>[
      message(id: 11, body: 'Reply while sending'),
      message(id: 12, role: 'visitor', body: 'My message', sentBy: 'human'),
      message(
        id: 13,
        role: 'visitor',
        body: 'Another device message',
        sentBy: 'human',
      ),
    ]) {
      connector.emitMessageCreated(<String, Object?>{'message': eventMessage});
    }
    expect(controller.state.messages, hasLength(1));
    expect(
      controller.state.messages
          .where((message) => message.body == 'My message'),
      hasLength(1),
    );
    expect(
      controller.state.messages.last.status,
      WisperBotMessageStatus.pending,
    );
    expect(controller.state.messages.single.body, 'My message');

    releaseSend.complete();
    final sent = await send;

    expect(controller.state.messages, hasLength(3));
    expect(controller.state.messages[1].localId, sent.localId);
    expect(controller.state.messages[1].serverId, 12);
    expect(
      controller.state.messages[1].status,
      WisperBotMessageStatus.sent,
    );
    expect(controller.state.messages.last.body, 'Another device message');
    expect(controller.state.pendingCount, 0);

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('ambiguous send becomes unconfirmed and cannot be retried', () async {
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      throw http.ClientException('connection dropped');
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await expectLater(
      controller.sendText('Possibly sent'),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.network,
        ),
      ),
    );

    final local = controller.state.messages.single;
    expect(local.status, WisperBotMessageStatus.unconfirmed);
    expect(
      () => controller.retryMessage(local.localId),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.validation,
        ),
      ),
    );

    await controller.dispose();
    await client.close();
  });

  test('ambiguous image upload remains unconfirmed and is sent once', () async {
    var uploadCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        uploadCalls++;
        throw http.ClientException('connection dropped after upload');
      }
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await expectLater(
      controller.sendImage(
        WisperBotUpload(
          bytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
          filename: 'screenshot.png',
          mimeType: 'image/png',
        ),
        caption: 'Please review this',
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.network,
        ),
      ),
    );

    expect(uploadCalls, 1);
    expect(controller.state.messages, hasLength(1));
    final local = controller.state.messages.single;
    expect(local.type, WisperBotMessageType.image);
    expect(local.status, WisperBotMessageStatus.unconfirmed);
    expect(
      () => controller.retryMessage(local.localId),
      throwsA(isA<WisperBotException>()),
    );

    await controller.dispose();
    await client.close();
  });

  test('pending image upload keeps local preview bytes until confirmed',
      () async {
    final sendStarted = Completer<void>();
    final sendResponse = Completer<http.Response>();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        sendStarted.complete();
        return sendResponse.future;
      }
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    final upload = WisperBotUpload(
      bytes: Uint8List.fromList(<int>[137, 80, 78, 71]),
      filename: 'screenshot.png',
      mimeType: 'image/png',
    );
    final send = controller.sendImage(upload, caption: 'Please review this');
    await sendStarted.future;

    final pending = controller.state.messages.single;
    expect(pending.status, WisperBotMessageStatus.pending);
    expect(pending.type, WisperBotMessageType.image);
    expect(pending.localUpload?.filename, 'screenshot.png');
    expect(pending.localUpload?.bytes, upload.bytes);

    sendResponse.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 4,
            role: 'visitor',
            type: 'image',
            body: 'Please review this',
            sentBy: 'human',
            attachmentUrl: 'https://cdn.example.com/screenshot.png',
            filename: 'screenshot.png',
            mimeType: 'image/png',
          ),
          'handoff': <String, Object?>{
            'enabled': true,
            'eligible': false,
            'status': 'bot',
          },
        }),
        200,
      ),
    );
    await send;

    final confirmed = controller.state.messages.single;
    expect(confirmed.status, WisperBotMessageStatus.sent);
    expect(confirmed.localUpload?.filename, 'screenshot.png');
    expect(confirmed.attachment?.filename, 'screenshot.png');

    await controller.dispose();
    await client.close();
  });

  test('pending audio upload keeps local preview bytes until confirmed',
      () async {
    final sendStarted = Completer<void>();
    final sendResponse = Completer<http.Response>();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      if (request.method == 'POST' && request.url.path.endsWith('/messages')) {
        sendStarted.complete();
        return sendResponse.future;
      }
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    final upload = WisperBotUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      filename: 'voice.wav',
      mimeType: 'audio/wav',
    );
    final send = controller.sendAudio(upload);
    await sendStarted.future;

    final pending = controller.state.messages.single;
    expect(pending.status, WisperBotMessageStatus.pending);
    expect(pending.type, WisperBotMessageType.audio);
    expect(pending.localUpload?.filename, 'voice.wav');
    expect(pending.localUpload?.bytes, upload.bytes);

    sendResponse.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 5,
            role: 'visitor',
            type: 'audio',
            body: 'Voice message',
            sentBy: 'human',
            attachmentUrl: 'https://cdn.example.com/voice.wav',
            filename: 'voice.wav',
            mimeType: 'audio/wav',
          ),
          'handoff': <String, Object?>{
            'enabled': true,
            'eligible': false,
            'status': 'bot',
          },
        }),
        200,
      ),
    );
    await send;

    final confirmed = controller.state.messages.single;
    expect(confirmed.status, WisperBotMessageStatus.sent);
    expect(confirmed.localUpload?.filename, 'voice.wav');
    expect(confirmed.attachment?.filename, 'voice.wav');

    await controller.dispose();
    await client.close();
  });
}
