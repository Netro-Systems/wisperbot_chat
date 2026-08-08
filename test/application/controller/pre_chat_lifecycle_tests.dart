part of 'chat_controller_test.dart';

void registerPreChatLifecycleTests(WisperBotConfig config) {
  test('required pre-chat reuses the token-bound session', () async {
    final requests = <http.Request>[];
    final httpClient = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode(sessionResponse(requirePreChat: true)),
        200,
      );
    });
    final store = MemorySessionStore();
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await controller.initialize();
    expect(controller.state.phase, WisperBotChatPhase.awaitingPreChat);

    await controller.submitPreChat(
      const WisperBotPreChatData(
        name: 'Jane Doe',
        email: 'jane@example.com',
      ),
    );
    expect(requests, hasLength(2));
    expect(requests.last.headers['X-Widget-Token'], 'token-1');
    final body = jsonDecode(requests.last.body) as Map<String, dynamic>;
    expect(body['visitor_id'], 'visitor-1');
    expect(body['name'], 'Jane Doe');
    expect(body['email'], 'jane@example.com');
    expect(controller.state.phase, WisperBotChatPhase.ready);
    expect(store.values.values.single.preChatCompleted, isTrue);

    await controller.dispose();
    await client.close();
  });

  test('pre-chat validates required fields and rejects unknown requirements',
      () async {
    var unknownField = false;
    final httpClient = MockClient((_) async {
      final response = sessionResponse(requirePreChat: true);
      if (unknownField) {
        final widget = response['config']! as Map<String, Object?>;
        widget['prechat_fields'] = <String>['phone'];
      }
      return http.Response(jsonEncode(response), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    await controller.initialize();

    await expectLater(
      controller.submitPreChat(const WisperBotPreChatData()),
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

    unknownField = true;
    final unknownClient = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final unknownController = WisperBotChatController(client: unknownClient);
    await expectLater(
      unknownController.initialize(),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.unsupported,
        ),
      ),
    );
    await unknownController.dispose();
    await unknownClient.close();
  });

  test('pre-chat skips when user data or stored completion satisfies fields',
      () async {
    final userStore = MemorySessionStore();
    final userConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      user: const WisperBotUser(
        name: 'Jane Doe',
        email: 'jane@example.com',
      ),
      polling: config.polling,
    );
    final responseClient = MockClient(
      (_) async => http.Response(
        jsonEncode(sessionResponse(requirePreChat: true)),
        200,
      ),
    );
    final userClient = WisperBotClient(
      config: userConfig,
      httpClient: responseClient,
      sessionStore: userStore,
    );
    final userController = WisperBotChatController(client: userClient);
    await userController.initialize();
    expect(userController.state.phase, WisperBotChatPhase.ready);
    await userController.dispose();
    await userClient.close();

    final stored = MemorySessionStore();
    final namespace = sessionNamespace(config: config, user: null);
    stored.values[namespace] = WisperBotStoredSession(
      visitorId: 'visitor-1',
      token: 'token-1',
      savedAt: DateTime.utc(2026, 8, 1),
      preChatCompleted: true,
    );
    final restoredClient = WisperBotClient(
      config: config,
      httpClient: responseClient,
      sessionStore: stored,
    );
    final restoredController = WisperBotChatController(client: restoredClient);
    await restoredController.initialize();
    expect(restoredController.state.phase, WisperBotChatPhase.ready);
    await restoredController.dispose();
    await restoredClient.close();
  });

  test('steady polling pauses in background and without listeners', () async {
    const pollingConfig = WisperBotConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      polling: WisperBotPollingConfig(
        visibleInterval: Duration(seconds: 3),
        idleInterval: Duration(seconds: 3),
        failureMaxInterval: Duration(seconds: 3),
      ),
    );
    var pollCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(jsonEncode(sessionResponse()), 200);
      }
      pollCalls++;
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: pollingConfig,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
    );
    final controller = WisperBotChatController(client: client);
    final subscription = controller.states.listen((_) {});
    try {
      await controller.initialize();
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(pollCalls, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(pollCalls, 1);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(pollCalls, 2);

      await subscription.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 3200));
      expect(pollCalls, 2);
    } finally {
      await subscription.cancel();
      await controller.dispose();
      await client.close();
    }
  });
}
