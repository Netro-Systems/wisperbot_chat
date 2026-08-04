import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/session_scope.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = WisperBotConfig(
    widgetKey: 'test-widget',
    apiBaseUrl: 'https://chat.example.com/base/',
    polling: WisperBotPollingConfig(
      visibleInterval: Duration(minutes: 1),
      idleInterval: Duration(minutes: 1),
      failureMaxInterval: Duration(minutes: 1),
    ),
  );

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
    expect(controller.state.capabilities.images, isTrue);
    expect(controller.state.unreadCount, isNull);
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

  test('performs one controlled restoration after an expired poll token',
      () async {
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

  test('send echo does not advance poll cursor and poll deduplicates by id',
      () async {
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

  test('poll defers a visitor echo while its send is still in flight',
      () async {
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
      controller.state.messages
          .where((message) => message.body == 'My message'),
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

  test('required pre-chat is rejected honestly until bootstrap exists',
      () async {
    final httpClient = MockClient((request) async => http.Response(
          jsonEncode(sessionResponse(requirePreChat: true)),
          200,
        ));
    final store = MemorySessionStore();
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: store,
    );
    final controller = WisperBotChatController(client: client);

    await expectLater(
      controller.initialize(),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.configuration,
        ),
      ),
    );
    expect(controller.state.phase, WisperBotChatPhase.failure);
    expect(store.values, isEmpty);

    await controller.dispose();
    await client.close();
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

  test('realtime delivers messages and polling alone advances the cursor',
      () async {
    final transport = _FakeRealtimeTransport();
    final pollAfter = <String?>[];
    var authCalls = 0;
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(
            sessionResponse(
              capabilities: <String, Object?>{'realtime': true},
              realtime: <String, Object?>{
                'provider': 'pusher',
                'key': 'public-key',
                'cluster': 'mt1',
                'channel': 'private-widget.opaque',
                'auth_endpoint': '/widget/v1/broadcasting/auth',
              },
            ),
          ),
          200,
        );
      }
      if (request.url.path.endsWith('/broadcasting/auth')) {
        authCalls++;
        expect(request.headers['X-Widget-Token'], 'token-1');
        return http.Response(
            jsonEncode(<String, String>{'auth': 'signed'}), 200);
      }
      pollAfter.add(request.url.queryParameters['after']);
      return http.Response(jsonEncode(pollResponse()), 200);
    });
    final client = WisperBotClient(
      config: config,
      httpClient: httpClient,
      sessionStore: MemorySessionStore(),
      realtimeTransport: transport,
    );
    final controller = WisperBotChatController(client: client);
    final subscription = controller.states.listen((_) {});

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(authCalls, 1);
    expect(controller.state.realtime, WisperBotRealtimeStatus.connected);

    transport.emit(
      WisperBotRealtimeEvent(
        name: 'WidgetMessageSent',
        data: jsonEncode(message(id: 9, body: 'Realtime reply')),
      ),
    );
    expect(controller.state.messages.single.body, 'Realtime reply');

    await controller.refresh();
    expect(pollAfter, isNotEmpty);
    expect(pollAfter.every((value) => value == '0'), isTrue);

    await subscription.cancel();
    await Future<void>.delayed(Duration.zero);
    expect(transport.connection.closed, isTrue);
    await controller.dispose();
    await client.close();
  });
}

class _FakeRealtimeTransport implements WisperBotRealtimeTransport {
  late void Function(WisperBotRealtimeEvent event) _onEvent;
  final _FakeRealtimeConnection connection = _FakeRealtimeConnection();

  @override
  Future<WisperBotRealtimeConnection> connect({
    required WisperBotRealtimeSettings settings,
    required WisperBotRealtimeAuthorizer authorize,
    required void Function(WisperBotRealtimeEvent event) onEvent,
    required void Function(WisperBotRealtimeStatus status) onStatus,
  }) async {
    _onEvent = onEvent;
    expect(settings.channel, 'private-widget.opaque');
    final authorization = await authorize('1234.5678', settings.channel);
    expect(authorization.auth, 'signed');
    onStatus(WisperBotRealtimeStatus.connected);
    return connection;
  }

  void emit(WisperBotRealtimeEvent event) => _onEvent(event);
}

class _FakeRealtimeConnection implements WisperBotRealtimeConnection {
  bool closed = false;

  @override
  Future<void> close() async => closed = true;
}
