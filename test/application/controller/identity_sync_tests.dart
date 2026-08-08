part of 'chat_controller_test.dart';

void registerIdentitySyncTests(WisperBotConfig config) {
  test('identity switch never sends the previous identity token', () async {
    final headers = <String?>[];
    final bodies = <Map<String, dynamic>>[];
    var count = 0;
    final httpClient = MockClient((request) async {
      headers.add(request.headers['X-Widget-Token']);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      count++;
      return http.Response(
        jsonEncode(
          sessionResponse(
            visitorId: 'visitor-$count',
            token: 'token-$count',
          ),
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

    await controller.updateUser(
      const WisperBotUser(
        externalId: 'customer-1',
        signature:
            '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      ),
    );

    expect(headers, <String?>[null, null]);
    expect(bodies.last['external_id'], 'customer-1');
    expect(bodies.last.containsKey('visitor_id'), isFalse);
    expect(controller.state.messages, isEmpty);

    await controller.updateUser(null);
    expect(headers, <String?>[null, null, null]);
    expect(bodies.last.containsKey('external_id'), isFalse);
    expect(bodies.last.containsKey('visitor_id'), isFalse);

    await controller.dispose();
    await client.close();
  });

  test('unsigned profile-only sessions remain memory-only', () async {
    final store = MemorySessionStore();
    final client = WisperBotClient(
      config: const WisperBotConfig(
        widgetKey: 'test-widget',
        apiBaseUrl: 'https://chat.example.com',
        user: WisperBotUser(name: 'Unverified display name'),
      ),
      httpClient: MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();

    expect(store.reads, isEmpty);
    expect(store.writes, isEmpty);
    expect(store.values, isEmpty);

    await controller.dispose();
    await client.close();
  });

  test('typing is throttled and human handoff reflects server state', () async {
    final typingValues = <bool>[];
    var handoffCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        final response = sessionResponse();
        response['handoff'] = <String, Object?>{
          'enabled': true,
          'eligible': true,
          'status': 'bot',
        };
        return http.Response(jsonEncode(response), 200);
      }
      if (request.url.path.endsWith('/typing')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        typingValues.add(body['is_typing'] as bool);
        return http.Response('{"ok":true}', 200);
      }
      if (request.url.path.endsWith('/handoff')) {
        handoffCalls++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'handoff': <String, Object?>{
              'enabled': true,
              'eligible': false,
              'status': 'connected',
            },
          }),
          200,
        );
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

    await controller.setTyping(true);
    await controller.setTyping(true);
    await controller.setTyping(false);
    await controller.requestHumanAgent();

    expect(typingValues, <bool>[true, false]);
    expect(handoffCalls, 1);
    expect(
      controller.state.handoff.status,
      WisperBotHandoffStatus.connected,
    );

    await controller.dispose();
    await client.close();
  });

  test('concurrent refresh calls never overlap transport requests', () async {
    final releasePoll = Completer<void>();
    var activePolls = 0;
    var maximumActivePolls = 0;
    var pollCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      pollCalls++;
      activePolls++;
      maximumActivePolls =
          activePolls > maximumActivePolls ? activePolls : maximumActivePolls;
      await releasePoll.future;
      activePolls--;
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    final first = controller.refresh();
    final second = controller.refresh();
    await Future<void>.delayed(Duration.zero);
    expect(pollCalls, 1);
    releasePoll.complete();
    await Future.wait<void>(<Future<void>>[first, second]);

    expect(maximumActivePolls, 1);

    await controller.dispose();
    await client.close();
  });
}
