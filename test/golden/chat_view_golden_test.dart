import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import '../support/support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const config = WisperBotConfig(
    widgetKey: 'test-widget',
    apiBaseUrl: 'https://chat.example.com',
    polling: WisperBotPollingConfig(
      visibleInterval: Duration(minutes: 1),
      idleInterval: Duration(minutes: 1),
      failureMaxInterval: Duration(minutes: 1),
    ),
  );

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.physicalSize = const Size(400, 800);
    view.devicePixelRatio = 1;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('loading presentation remains pixel stable', (tester) async {
    final response = Completer<http.Response>();
    final runtime = _Runtime(config, MockClient((_) => response.future));

    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_loading.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
    await runtime.dispose();
  });

  testWidgets('ready conversation remains pixel stable', (tester) async {
    final runtime = _Runtime(
      config,
      MockClient((request) async => http.Response(
            jsonEncode(sessionResponse(messages: <Map<String, Object?>>[
              message(id: 1, body: 'How can we help today?'),
              message(
                id: 2,
                role: 'visitor',
                body: 'I need help with my order.',
                sentBy: 'human',
              ),
            ])),
            200,
          )),
    );

    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_ready.png'),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('required pre-chat remains pixel stable', (tester) async {
    final runtime = _Runtime(
      config,
      MockClient((_) async => http.Response(
            jsonEncode(sessionResponse(requirePreChat: true)),
            200,
          )),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_pre_chat.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('terminal failure remains pixel stable', (tester) async {
    final runtime = _Runtime(
      config,
      MockClient((_) async => http.Response('{"message":"missing"}', 404)),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_failure.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('support-unavailable state remains pixel stable', (tester) async {
    final runtime = _Runtime(
      config,
      MockClient((_) async => http.Response(
            jsonEncode(sessionResponse(online: false)),
            200,
          )),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_unavailable.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('reconnecting state remains pixel stable', (tester) async {
    var calls = 0;
    final runtime = _Runtime(
      config,
      MockClient((_) async {
        calls++;
        if (calls == 1) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        return http.Response('{"message":"temporary"}', 503);
      }),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();
    await runtime.controller.refresh().catchError((_) {});
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_reconnecting.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('launcher remains pixel stable', (tester) async {
    final runtime = _Runtime(
      config,
      MockClient(
          (_) async => http.Response(jsonEncode(sessionResponse()), 200)),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatLauncher(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await expectLater(
      find.byType(WisperBotChatLauncher),
      matchesGoldenFile('goldens/chat_launcher.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('handoff and media composer remain pixel stable', (tester) async {
    final response = sessionResponse();
    response['handoff'] = <String, Object?>{
      'enabled': true,
      'eligible': true,
      'status': 'bot',
    };
    final mediaConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      polling: config.polling,
      mediaAdapter: const _GoldenMediaAdapter(),
    );
    final runtime = _Runtime(
      mediaConfig,
      MockClient((_) async => http.Response(jsonEncode(response), 200)),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: mediaConfig, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_handoff_media.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('small high-text-scale layout remains pixel stable',
      (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.physicalSize = const Size(320, 568);
    final runtime = _Runtime(
      config,
      MockClient(
          (_) async => http.Response(jsonEncode(sessionResponse()), 200)),
    );
    await tester.pumpWidget(_goldenApp(
      WisperBotChatView(config: config, controller: runtime.controller),
      textScaler: const TextScaler.linear(2),
    ));
    await tester.pump();
    await tester.pump();

    await expectLater(
      find.byType(WisperBotChatView),
      matchesGoldenFile('goldens/chat_small_text_scale.png'),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}

Widget _goldenApp(
  Widget child, {
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, current) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: true,
          textScaler: textScaler,
        ),
        child: current!,
      ),
      home: Scaffold(body: child),
    );

final class _GoldenMediaAdapter implements WisperBotMediaAdapter {
  const _GoldenMediaAdapter();

  @override
  Future<void> cancelAudioRecording() async {}

  @override
  Future<WisperBotUpload?> pickImage() async => null;

  @override
  Future<void> startAudioRecording() async {}

  @override
  Future<WisperBotUpload?> stopAudioRecording() async => null;
}

final class _Runtime {
  _Runtime(WisperBotConfig config, http.Client httpClient)
      : client = WisperBotClient(
          config: config,
          httpClient: httpClient,
          sessionStore: MemorySessionStore(),
        ) {
    controller = WisperBotChatController(client: client);
  }

  final WisperBotClient client;
  late final WisperBotChatController controller;

  Future<void> dispose() async {
    await controller.dispose();
    await client.close();
  }
}
