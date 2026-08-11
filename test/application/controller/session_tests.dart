part of 'chat_controller_test.dart';

void registerSessionTests(WisperBotConfig config) {
  test('parses history, unknown fields, and unknown enum values safely',
      () async {
    final store = MemorySessionStore();
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/base/widget/v1/session');
      return http.Response(
        jsonEncode(
          sessionResponse(
            messages: <Map<String, Object?>>[
              message(id: 3, role: 'future-role', type: 'future-type'),
              message(id: 2, body: 'Known message'),
            ],
          ),
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

    expect(controller.state.phase, WisperBotChatPhase.ready);
    expect(
        controller.state.messages.map((item) => item.serverId), <int?>[2, 3]);
    expect(
      controller.state.messages.last.role,
      WisperBotMessageRole.unknown,
    );
    expect(
      controller.state.messages.last.type,
      WisperBotMessageType.unknown,
    );
    expect(store.values.values.single.token, 'token-1');

    await controller.dispose();
    await client.close();
  });

  test('uses the web-widget primary fallback for missing or invalid colors',
      () async {
    var calls = 0;
    final httpClient = MockClient((request) async {
      calls++;
      final response = sessionResponse();
      final widget = response['config']! as Map<String, Object?>;
      if (calls == 1) {
        widget.remove('primary_color');
      } else {
        widget['primary_color'] = 'not-a-color';
      }
      return http.Response(jsonEncode(response), 200);
    });

    for (var index = 0; index < 2; index++) {
      final client = WisperBotClient(
        config: config,
        httpClient: httpClient,
        sessionStore: MemorySessionStore(),
      );
      final controller = WisperBotChatController(client: client);

      await controller.initialize();

      expect(controller.state.widget?.primaryColorHex, '#ff762e');
      await controller.dispose();
      await client.close();
    }
  });
}
