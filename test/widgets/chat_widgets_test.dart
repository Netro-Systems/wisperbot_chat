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
    expect(find.text('Powered by WisperBot'), findsOneWidget);
    expect(find.bySemanticsLabel('Support avatar'), findsWidgets);
    expect(find.bySemanticsLabel('Send message'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Type your message…'),
      findsOneWidget,
    );
    expect(runtime.controller.state.messages, isEmpty);

    final sendButtonSize = tester.getSize(
      find.widgetWithIcon(IconButton, Icons.send_rounded),
    );
    expect(sendButtonSize.width, greaterThanOrEqualTo(48));
    expect(sendButtonSize.height, greaterThanOrEqualTo(48));

    await tester.enterText(find.byType(TextField), 'Hello SDK');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    expect(sendCalls, 1);
    expect(find.text('Hello SDK'), findsOneWidget);
    expect(find.text('Welcome to the test chat'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    final sent = runtime.controller.state.messages.single;
    final bubbleSize = tester.getSize(
      find.byKey(
        ValueKey<String>('wisperbot-message-bubble-${sent.localId}'),
      ),
    );
    expect(bubbleSize.width, lessThan(300));

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
    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('wisperbot-chat-header')),
    );
    expect(
      header.color,
      const Color(0xFF6258F9),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('built-in brand colors ignore API and host primary colors',
      (tester) async {
    const brandConfig = WisperBotConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      useApiColors: false,
      polling: WisperBotPollingConfig(
        visibleInterval: Duration(minutes: 1),
        idleInterval: Duration(minutes: 1),
        failureMaxInterval: Duration(minutes: 1),
      ),
    );
    final runtime = _runtime(
      brandConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      Stack(
        children: <Widget>[
          WisperBotChatView(
            config: brandConfig,
            controller: runtime.controller,
          ),
          WisperBotChatLauncher(
            config: brandConfig,
            controller: runtime.controller,
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump();

    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('wisperbot-chat-header')),
    );
    expect(header.color, const Color(0xFFFF762E));
    final canvases = tester.widgetList<ColoredBox>(find.byType(ColoredBox));
    expect(
      canvases.any((canvas) => canvas.color == const Color(0xFFF7F8FA)),
      isTrue,
    );
    final launcher = tester.widget<FloatingActionButton>(
      find.byType(FloatingActionButton),
    );
    expect(launcher.backgroundColor, const Color(0xFFFF762E));

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('branded header honors theme override and close action',
      (tester) async {
    const themedConfig = WisperBotConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      useApiColors: false,
      theme: WisperBotThemeData(primaryColor: Color(0xFF087F5B)),
      polling: WisperBotPollingConfig(
        visibleInterval: Duration(minutes: 1),
        idleInterval: Duration(minutes: 1),
        failureMaxInterval: Duration(minutes: 1),
      ),
    );
    final runtime = _runtime(
      themedConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );
    var closeCalls = 0;

    await tester.pumpWidget(_app(
      WisperBotChatView(
        config: themedConfig,
        controller: runtime.controller,
        onClose: () => closeCalls++,
      ),
    ));
    await tester.pump();
    await tester.pump();

    final header = tester.widget<Material>(
      find.byKey(const ValueKey<String>('wisperbot-chat-header')),
    );
    expect(header.color, const Color(0xFF087F5B));
    expect(find.text('Test support'), findsOneWidget);
    expect(find.byTooltip('Close chat'), findsOneWidget);

    await tester.tap(find.byTooltip('Close chat'));
    expect(closeCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('custom full-screen app bar remains host-owned', (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      WisperBotChatScreen(
        config: config,
        controller: runtime.controller,
        appBar: AppBar(title: const Text('Host support title')),
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Host support title'), findsOneWidget);
    expect(find.text('Test support'), findsNothing);
    expect(find.byType(TextField), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('default layout fits a small phone at 200 percent text scale',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: child!,
        ),
        home: WisperBotChatView(
          config: config,
          controller: runtime.controller,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Test support'), findsOneWidget);
    expect(find.text('Powered by WisperBot'), findsOneWidget);

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
