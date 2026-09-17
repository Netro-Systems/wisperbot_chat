part of 'chat_controller_test.dart';

void registerDeliveryEdgeCaseTests(WisperBotConfig config) {
  test('initialization paginates a full first history page', () async {
    final initialMessages = List<Map<String, Object?>>.generate(
      100,
      (index) => message(id: index + 1, body: 'Message ${index + 1}'),
    );
    var refreshCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(messages: initialMessages)),
          200,
        );
      }
      if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
        refreshCalls++;
        expect(request.url.queryParameters['after'], '100');
        return http.Response(
          jsonEncode(
            pollResponse(messages: <Map<String, Object?>>[
              message(id: 101, body: 'Page two'),
            ]),
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

    expect(refreshCalls, 1);
    expect(controller.state.messages, hasLength(101));
    expect(controller.state.messages.last.serverId, 101);

    await controller.dispose();
    await client.close();
  });

  test(
      'ambiguous send is not heuristically merged with an identical realtime echo',
      () async {
    final connector = _FakeWidgetRealtimeConnector();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
          200,
        );
      }
      if (request.method == 'POST') {
        throw http.ClientException('connection dropped after write');
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

    await expectLater(controller.sendText('Same words'), throwsException);
    connector.emitMessageCreated(<String, Object?>{
      'message': message(
        id: 20,
        role: 'visitor',
        body: 'Same words',
        sentBy: 'human',
      ),
    });

    final matches = controller.state.messages
        .where((item) => item.body == 'Same words')
        .toList();
    expect(matches, hasLength(2));
    expect(
      matches.map((item) => item.status),
      containsAll(<WisperBotMessageStatus>[
        WisperBotMessageStatus.unconfirmed,
        WisperBotMessageStatus.sent,
      ]),
    );
    expect(matches.where((item) => item.serverId == null), hasLength(1));
    expect(matches.where((item) => item.serverId == 20), hasLength(1));

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('send operations are serialized in invocation order', () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var sendCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      sendCalls++;
      if (sendCalls == 1) {
        firstStarted.complete();
        await releaseFirst.future;
      }
      return http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 30 + sendCalls,
            role: 'visitor',
            body: sendCalls == 1 ? 'First' : 'Second',
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
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    final first = controller.sendText('First');
    await firstStarted.future;
    final second = controller.sendText('Second');
    await Future<void>.delayed(Duration.zero);
    expect(sendCalls, 1);

    releaseFirst.complete();
    await Future.wait(<Future<WisperBotMessage>>[first, second]);
    expect(sendCalls, 2);
    expect(
      controller.state.messages.map((item) => item.body),
      <String>['First', 'Second'],
    );

    await controller.dispose();
    await client.close();
  });

  test('typing throttle expires locally and sends a single stop update',
      () async {
    final typingValues = <bool>[];
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      typingValues.add(body['is_typing'] as bool);
      return http.Response('{"ok":true}', 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await controller.setTyping(true);
    await controller.setTyping(true);
    expect(typingValues, <bool>[true]);
    expect(controller.state.visitorTyping, isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 4200));
    expect(controller.state.visitorTyping, isFalse);
    expect(typingValues, <bool>[true, false]);

    await controller.dispose();
    await client.close();
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('agent typing expires when no later realtime event renews it', () async {
    final connector = _FakeWidgetRealtimeConnector();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
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
    connector.emitTypingChanged(<String, Object?>{
      'agent_typing': <String, Object?>{
        'is_typing': true,
        'name': 'Taylor',
      },
    });
    expect(controller.state.agentTyping?.name, 'Taylor');

    await Future<void>.delayed(const Duration(milliseconds: 6200));
    expect(controller.state.agentTyping, isNull);

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  }, timeout: const Timeout(Duration(seconds: 10)));

  test('reset deletes the active credential scope and returns to idle',
      () async {
    final store = MemorySessionStore();
    final client = WisperBotClient(
      config: config,
      httpClient: MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await controller.resetSession();

    expect(store.deletes, hasLength(1));
    expect(store.values, isEmpty);
    expect(controller.state.phase, WisperBotChatPhase.idle);

    await controller.dispose();
    await client.close();
  });
}
