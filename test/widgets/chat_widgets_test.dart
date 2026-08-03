import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import '../support/fakes.dart';

void main() {
  const config = WisperBotConfig(
    widgetKey: 'test-widget',
    apiBaseUrl: 'https://chat.example.com',
    polling: WisperBotPollingConfig(
      visibleInterval: Duration(minutes: 1),
      idleInterval: Duration(minutes: 1),
      failureMaxInterval: Duration(minutes: 1),
    ),
  );

  testWidgets('embedded view exposes an accessible loading state',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.bySemanticsLabel('Connecting to chat'), findsOneWidget);

    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('ready empty view renders welcome text and composer semantics',
      (tester) async {
    var sendCalls = 0;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        sendCalls++;
        return http.Response(
          jsonEncode(<String, Object?>{
            'message': message(
              id: 1,
              role: 'visitor',
              body: 'Hello SDK',
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
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome to the test chat'), findsOneWidget);
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Write a message'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Hello SDK');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump(const Duration(milliseconds: 100));

    expect(sendCalls, 1);
    expect(find.text('Hello SDK'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('terminal server failure is actionable and hides composer',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient((_) async => http.Response('{}', 404)),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('The widget is missing or disabled.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('custom empty builder receives immutable ready state',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(
        config: config,
        controller: runtime.controller,
        emptyBuilder: (_, state) => Text('Custom ${state.phase.name}'),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Custom ready'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('launcher has an accessible 48dp target and server alignment',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      Stack(
        children: <Widget>[
          const SizedBox.expand(),
          WisperBotChatLauncher(
            config: config,
            controller: runtime.controller,
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.bySemanticsLabel('Open chat'), findsWidgets);
    final size = tester.getSize(find.byType(FloatingActionButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('full-screen integration renders a title and embedded body',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      WisperBotChatScreen(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Test support'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

_TestRuntime _runtime(WisperBotConfig config, http.Client httpClient) {
  final client = WisperBotClient(
    config: config,
    httpClient: httpClient,
    sessionStore: MemorySessionStore(),
  );
  return _TestRuntime(
    client: client,
    controller: WisperBotChatController(client: client),
  );
}

class _TestRuntime {
  const _TestRuntime({required this.client, required this.controller});

  final WisperBotClient client;
  final WisperBotChatController controller;

  Future<void> dispose() async {
    await controller.dispose();
    await client.close();
  }
}
