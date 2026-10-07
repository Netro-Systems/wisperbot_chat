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

    final client = WisperBotClient.fromConfig(
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

    // Resolving clears the handoff before broadcasting the activity.
    connector.emitHandoffUpdated({
      'handoff': {'enabled': true, 'eligible': true, 'status': 'bot'},
    });
    connector.emitMessageCreated({
      'message': message(id: 10, type: 'event', body: 'Resolved by Taylor')
        ..addAll({
          'kind': 'activity',
          'status': 'delivered',
          'sent_by': 'system',
          'agent_name': 'Taylor',
          'activity': {
            'type': 'conversation.resolved',
            'actor_name': 'Taylor',
          },
        }),
    });
    await Future<void>.delayed(Duration.zero);
    expect(controller.state.messages.last.body, 'Resolved by Taylor');
    expect(controller.state.messages.last.isActivity, isTrue);

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });

  test('realtime status event updates a sent message without downgrading it',
      () async {
    final connector = _FakeWidgetRealtimeConnector();
    final visitor = message(
      id: 7,
      role: 'visitor',
      body: 'Seen yet?',
      sentBy: 'human',
    );
    visitor['status'] = 'sent';
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(
            sessionResponse(
              realtimeKey: 'pusher-key',
              messages: <Map<String, Object?>>[visitor],
            ),
          ),
          200,
        );
      }
      if (request.url.path.endsWith('/messages')) {
        return http.Response(jsonEncode(pollResponse()), 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    final client = WisperBotClient.fromConfig(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
      realtimeConnector: connector,
    );
    final controller = WisperBotChatController(client: client);
    final statesSub = controller.states.listen((_) {});

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    connector.emitMessageStatusUpdated(<String, Object?>{
      'id': 7,
      'status': 'read',
    });
    expect(
        controller.state.messages.single.status, WisperBotMessageStatus.read);

    connector.emitMessageStatusUpdated(<String, Object?>{
      'id': 7,
      'status': 'delivered',
    });
    expect(
        controller.state.messages.single.status, WisperBotMessageStatus.read);

    await statesSub.cancel();
    await controller.dispose();
    await client.close();
  });
}

final class _FakeWidgetRealtimeConnector implements WidgetRealtimeConnector {
  int startCalls = 0;
  int stopCalls = 0;
  int? lastConversationId;
  WidgetRealtimePayloadCallback? _onMessageCreated;
  WidgetRealtimePayloadCallback? _onMessageStatusUpdated;
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
    WidgetRealtimePayloadCallback? onMessageStatusUpdated,
    WidgetRealtimePayloadCallback? onTypingChanged,
    WidgetRealtimePayloadCallback? onHandoffUpdated,
    WidgetRealtimeErrorCallback? onError,
  }) async {
    startCalls++;
    lastConversationId = conversationId;
    _onMessageCreated = onMessageCreated;
    _onMessageStatusUpdated = onMessageStatusUpdated;
    _onTypingChanged = onTypingChanged;
    _onHandoffUpdated = onHandoffUpdated;
    onConnected?.call();
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    _onMessageCreated = null;
    _onMessageStatusUpdated = null;
    _onTypingChanged = null;
    _onHandoffUpdated = null;
  }

  void emitMessageCreated(Object? payload) => _onMessageCreated?.call(payload);

  void emitMessageStatusUpdated(Object? payload) =>
      _onMessageStatusUpdated?.call(payload);

  void emitTypingChanged(Object? payload) => _onTypingChanged?.call(payload);

  void emitHandoffUpdated(Object? payload) => _onHandoffUpdated?.call(payload);
}
