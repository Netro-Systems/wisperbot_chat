part of 'chat_controller_test.dart';

void registerRealtimeTests(WisperBotConfig config) {
  test('decodes session conversation id and optional realtime config',
      () async {
    final decoder = const WidgetResponseDecoder();
    final result = decoder.session(
      http.Response(
        jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
        200,
      ),
      preChatCompleted: false,
    );

    expect(result.conversationId, 42);
    expect(result.widget.realtime?.key, 'pusher-key');
    expect(
      result.widget.realtime?.authEndpoint.toString(),
      'https://chat.example.com/base/widget/v1/broadcasting/auth',
    );
  });

  test('realtime widget events merge messages and typing updates', () async {
    final connector = _FakeWidgetRealtimeConnector();
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(sessionResponse(realtimeKey: 'pusher-key')),
          200,
        );
      }
      if (request.url.path.endsWith('/messages')) {
        return http.Response(jsonEncode(pollResponse()), 200);
      }
      if (request.url.path.endsWith('/typing')) {
        return http.Response('{}', 200);
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
    await Future<void>.delayed(Duration.zero);

    expect(connector.startCalls, 1);
    expect(connector.lastConversationId, 42);

    connector.emitMessageCreated(<String, Object?>{
      'message': message(id: 9, role: 'agent', body: 'Realtime hello'),
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.messages.last.serverId, 9);
    expect(controller.state.messages.last.body, 'Realtime hello');

    connector.emitTypingChanged(<String, Object?>{
      'agent_typing': <String, Object?>{
        'is_typing': true,
        'name': 'Taylor',
      },
    });
    await Future<void>.delayed(Duration.zero);

    expect(controller.state.agentTyping?.name, 'Taylor');

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });
}

final class _FakeWidgetRealtimeConnector implements WidgetRealtimeConnector {
  int startCalls = 0;
  int? lastConversationId;
  WidgetRealtimePayloadCallback? _onMessageCreated;
  WidgetRealtimePayloadCallback? _onTypingChanged;
  WidgetRealtimePayloadCallback? _onHandoffUpdated;

  @override
  Future<void> start({
    required WisperBotRealtimeConfig config,
    required String widgetKey,
    required String token,
    required int conversationId,
    void Function()? onConnected,
    WidgetRealtimePayloadCallback? onMessageCreated,
    WidgetRealtimePayloadCallback? onTypingChanged,
    WidgetRealtimePayloadCallback? onHandoffUpdated,
    WidgetRealtimeErrorCallback? onError,
  }) async {
    startCalls++;
    lastConversationId = conversationId;
    _onMessageCreated = onMessageCreated;
    _onTypingChanged = onTypingChanged;
    _onHandoffUpdated = onHandoffUpdated;
    onConnected?.call();
  }

  @override
  Future<void> stop() async {
    _onMessageCreated = null;
    _onTypingChanged = null;
    _onHandoffUpdated = null;
  }

  void emitMessageCreated(Object? payload) => _onMessageCreated?.call(payload);

  void emitTypingChanged(Object? payload) => _onTypingChanged?.call(payload);

  void emitHandoffUpdated(Object? payload) => _onHandoffUpdated?.call(payload);
}
