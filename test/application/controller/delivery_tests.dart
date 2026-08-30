part of 'chat_controller_test.dart';

void registerDeliveryTests(WisperBotConfig config) {
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

  test('performs one controlled restoration after an expired poll token', () async {
    final store = MemorySessionStore();
    var sessionCalls = 0;
    var pollCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        sessionCalls++;
        return http.Response(
          jsonEncode(
            sessionResponse(
              visitorId: 'visitor-$sessionCalls',
              token: 'token-$sessionCalls',
            ),
          ),
          200,
        );
      }
      pollCalls++;
      expect(request.headers['X-Widget-Token'], 'token-1');
      return http.Response('{}', 401);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();
    await controller.refresh();

    expect(pollCalls, 1);
    expect(sessionCalls, 2);
    expect(controller.state.phase, WisperBotChatPhase.ready);
    expect(store.values.values.single.token, 'token-2');

    await controller.dispose();
    await client.close();
  });

  test('send echo does not advance poll cursor and poll deduplicates by id', () async {
    final store = MemorySessionStore();
    final pollAfter = <String?>[];
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
      pollAfter.add(request.url.queryParameters['after']);
      return http.Response(
        jsonEncode(
          pollResponse(messages: <Map<String, Object?>>[
            message(id: 11, body: 'Reply between IDs'),
            message(
              id: 12,
              role: 'visitor',
              body: 'My message',
              sentBy: 'human',
            ),
          ]),
        ),
        200,
      );
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();
    final sent = await controller.sendText('My message');
    await controller.refresh();

    expect(pollAfter, <String?>['10']);
    expect(
      controller.state.messages.map((item) => item.serverId),
      <int?>[10, 11, 12],
    );
    expect(controller.state.messages.last.localId, sent.localId);
    expect(
      controller.state.messages.last.sentBy,
      WisperBotSenderKind.visitor,
    );

    await controller.dispose();
    await client.close();
  });

  test('poll defers a visitor echo while its send is still in flight', () async {
    final sendStarted = Completer<void>();
    final releaseSend = Completer<void>();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
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
      return http.Response(
        jsonEncode(
          pollResponse(messages: <Map<String, Object?>>[
            message(id: 11, body: 'Reply while sending'),
            message(
              id: 12,
              role: 'visitor',
              body: 'My message',
              sentBy: 'human',
            ),
            message(
              id: 13,
              role: 'visitor',
              body: 'Another device message',
              sentBy: 'human',
            ),
          ]),
        ),
        200,
      );
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();
    final send = controller.sendText('My message');
    await sendStarted.future;
    await controller.refresh();
    expect(controller.state.messages, hasLength(2));
    expect(
      controller.state.messages.where((message) => message.body == 'My message'),
      hasLength(1),
    );
    expect(
      controller.state.messages.last.status,
      WisperBotMessageStatus.pending,
    );
    expect(
      controller.state.messages.first.body,
      'Reply while sending',
    );

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

  test('pending image upload keeps local preview bytes until confirmed', () async {
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

  test('pending audio upload keeps local preview bytes until confirmed', () async {
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
