import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/ui/remote_image.dart';

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

  testWidgets('embedded view shows only an accessible neutral shimmer',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(Icon), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-loading-shimmer')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-loading-header')),
      findsOneWidget,
    );
    final appBarLine = find.byKey(
      const ValueKey<String>('wisperbot-loading-appbar-line'),
    );
    expect(appBarLine, findsOneWidget);
    expect(tester.getSize(appBarLine).height, 3);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-loading-message-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-loading-composer')),
      findsOneWidget,
    );
    final canvasBottom = tester
        .getBottomRight(
          find.byKey(const ValueKey<String>('wisperbot-loading-canvas')),
        )
        .dy;
    final composerBottom = tester
        .getBottomRight(
          find.byKey(const ValueKey<String>('wisperbot-loading-composer')),
        )
        .dy;
    expect(canvasBottom - composerBottom, greaterThanOrEqualTo(28));
    expect(find.bySemanticsLabel('Connecting to chat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
    await runtime.dispose();
  });

  testWidgets('loading shimmer becomes static when motion is reduced',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: WisperBotChatView(
            config: config,
            controller: runtime.controller,
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(
          const ValueKey<String>('wisperbot-loading-shimmer'),
        ),
        matching: find.byType(ShaderMask),
      ),
      findsNothing,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('loading shimmer fits a short embedded container',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(_app(
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 240,
          height: 180,
          child: WisperBotChatView(
            config: config,
            controller: runtime.controller,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-loading-shimmer')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
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
    final supportLogo = tester.widget<Image>(
      find.byKey(const ValueKey<String>('wisperbot-support-logo')).first,
    );
    final supportLogoAsset = supportLogo.image as AssetImage;
    expect(supportLogoAsset.assetName, 'assets/images/logo.png');
    expect(supportLogoAsset.package, 'wisperbot_chat');
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

  testWidgets('default composer picks images and records voice through adapter',
      (tester) async {
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      mediaAdapter: mediaAdapter,
      polling: const WisperBotPollingConfig(
        visibleInterval: Duration(minutes: 1),
        idleInterval: Duration(minutes: 1),
        failureMaxInterval: Duration(minutes: 1),
      ),
    );
    var uploadCount = 0;
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          uploadCount++;
          final type = uploadCount == 1 ? 'image' : 'audio';
          return http.Response(
            jsonEncode(<String, Object?>{
              'message': message(
                id: uploadCount,
                role: 'visitor',
                type: type,
                body: type == 'image' ? 'Image attachment' : 'Voice message',
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
        }
        return http.Response(jsonEncode(pollResponse()), 200);
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(
        config: mediaConfig,
        controller: runtime.controller,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Attach image'), findsOneWidget);
    expect(find.byTooltip('Record voice message'), findsOneWidget);

    await tester.tap(find.byTooltip('Attach image'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.imagePicks, 1);
    final preview = find.byKey(
      const ValueKey<String>('wisperbot-image-preview'),
    );
    expect(preview, findsOneWidget);

    await tester.tap(
      find.descendant(of: preview, matching: find.text('Send')),
    );
    await tester.pumpAndSettle();
    expect(uploadCount, 1);
    expect(preview, findsNothing);

    await tester.tap(find.byTooltip('Record voice message'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.recordingStarts, 1);
    expect(
      find.bySemanticsLabel(RegExp('Recording voice message')),
      findsOneWidget,
    );
    expect(find.byTooltip('Stop and send voice message'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop and send voice message'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.recordingStops, 1);
    expect(uploadCount, 2);
    expect(find.text('Recording… tap stop to send'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('eligible handoff uses the human-agent prompt and connects',
      (tester) async {
    var handoffCalls = 0;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          final response = sessionResponse();
          response['handoff'] = <String, Object?>{
            'enabled': true,
            'eligible': true,
            'status': 'bot',
          };
          return http.Response(jsonEncode(response), 200);
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
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Prefer a person?'), findsOneWidget);
    expect(find.text('Human Agent'), findsOneWidget);
    await tester.tap(find.text('Human Agent'));
    await tester.pumpAndSettle();

    expect(handoffCalls, 1);
    expect(find.text('Connected to a human agent'), findsOneWidget);

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
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Open chat'), findsWidgets);
    final size = tester.getSize(find.byType(FloatingActionButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
    final logo = tester.widget<Image>(
      find.byKey(const ValueKey<String>('wisperbot-launcher-logo')),
    );
    final logoAsset = logo.image as AssetImage;
    expect(logoAsset.assetName, 'assets/images/logo.png');
    expect(logoAsset.package, 'wisperbot_chat');

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  for (final alignment in <Alignment?>[null, Alignment.topLeft]) {
    final alignmentName = alignment == null ? 'server' : 'custom';
    testWidgets('launcher zoom stays fixed with $alignmentName alignment',
        (tester) async {
      final response = Completer<http.Response>();
      final runtime = _runtime(
        config,
        MockClient((_) => response.future),
      );

      await tester.pumpWidget(_app(
        Stack(
          children: <Widget>[
            const SizedBox.expand(),
            WisperBotChatLauncher(
              config: config,
              controller: runtime.controller,
              alignment: alignment,
            ),
          ],
        ),
      ));

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.bySemanticsLabel('Open chat'), findsNothing);

      response.complete(http.Response(jsonEncode(sessionResponse()), 200));
      await tester.pump();

      final loadedLauncher = find.byKey(
        const ValueKey<String>('wisperbot-launcher-loaded'),
      );
      final transition = find.byKey(
        const ValueKey<String>('wisperbot-launcher-transition'),
      );
      final zoom = find.byKey(
        const ValueKey<String>('wisperbot-launcher-zoom'),
      );
      final fab = find.byType(FloatingActionButton);
      expect(loadedLauncher, findsOneWidget);
      expect(fab, findsOneWidget);
      expect(
        find.descendant(
          of: transition,
          matching: find.byType(FadeTransition),
        ),
        findsNothing,
      );

      final initialScale = tester.widget<ScaleTransition>(zoom);
      expect(initialScale.scale.value, 0);
      expect(initialScale.alignment, Alignment.center);
      final fixedCenter = tester.getCenter(fab);

      await tester.pump(const Duration(milliseconds: 120));
      expect(
        tester.widget<ScaleTransition>(zoom).scale.value,
        inExclusiveRange(0, 1),
      );
      expect(
        tester.getCenter(fab),
        offsetMoreOrLessEquals(fixedCenter, epsilon: 0.01),
      );

      await tester.pump(const Duration(milliseconds: 120));
      expect(tester.widget<ScaleTransition>(zoom).scale.value, 1);
      expect(
        tester.getCenter(fab),
        offsetMoreOrLessEquals(fixedCenter, epsilon: 0.01),
      );
      expect(find.bySemanticsLabel('Open chat'), findsWidgets);

      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.dispose();
    });
  }

  testWidgets('custom launcher builder retains loading-state control',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(_app(
      WisperBotChatLauncher(
        config: config,
        controller: runtime.controller,
        builder: (_, __, ___) => const Text('Custom launcher'),
      ),
    ));

    expect(find.text('Custom launcher'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();
    await runtime.dispose();
  });

  testWidgets('launcher skips its entrance transition for reduced motion',
      (tester) async {
    final response = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((_) => response.future),
    );

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: WisperBotChatLauncher(
            config: config,
            controller: runtime.controller,
          ),
        ),
      ),
    );

    expect(find.byType(FloatingActionButton), findsNothing);

    response.complete(http.Response(jsonEncode(sessionResponse()), 200));
    await tester.pump();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-launcher-transition')),
      findsNothing,
    );
    expect(find.bySemanticsLabel('Open chat'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('remote brand assets use contained web-widget sizing',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(
          jsonEncode(
            sessionResponse(
              avatarUrl: 'https://chat.example.com/support.png',
              launcherLogoUrl: 'https://chat.example.com/launcher.png',
            ),
          ),
          200,
        ),
      ),
    );

    await tester.pumpWidget(_app(
      Stack(
        children: <Widget>[
          WisperBotChatView(config: config, controller: runtime.controller),
          WisperBotChatLauncher(
            config: config,
            controller: runtime.controller,
          ),
        ],
      ),
    ));
    await tester.pump();
    await tester.pump();

    final images = find.byType(WisperBotRemoteImage);
    expect(images, findsNWidgets(3));
    final sizes = <Size>[
      for (var index = 0; index < 3; index++) tester.getSize(images.at(index)),
    ];
    expect(sizes.map((size) => size.width), contains(closeTo(20.16, 0.01)));
    expect(sizes.map((size) => size.width), contains(closeTo(15.68, 0.01)));
    expect(sizes.map((size) => size.width), contains(closeTo(32, 0.01)));

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

  testWidgets('bottom sheet tracks keyboard and restores its safe height',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final runtime = _runtime(
      config,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(
      Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => unawaited(
            WisperBotChat.open(
              context,
              config: config,
              controller: runtime.controller,
              presentation: WisperBotPresentation.bottomSheet,
            ),
          ),
          child: const Text('Open bottom sheet'),
        ),
      ),
    ));

    await tester.tap(find.text('Open bottom sheet'));
    await tester.pumpAndSettle();

    final sheet = find.byKey(
      const ValueKey<String>('wisperbot-bottom-sheet'),
    );
    expect(sheet, findsOneWidget);
    expect(tester.getSize(sheet).height, closeTo(768, 0.1));
    expect(find.byType(TextField), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pump();

    expect(tester.getSize(sheet).height, closeTo(480, 0.1));
    expect(
      tester.getBottomRight(find.byType(TextField)).dy,
      lessThanOrEqualTo(500),
    );

    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();

    expect(tester.getSize(sheet).height, closeTo(768, 0.1));
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byTooltip('Close chat'));
    await tester.pumpAndSettle();
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

class _FakeMediaAdapter implements WisperBotMediaAdapter {
  int imagePicks = 0;
  int recordingStarts = 0;
  int recordingStops = 0;
  int recordingCancels = 0;

  @override
  Future<WisperBotUpload?> pickImage() async {
    imagePicks++;
    return WisperBotUpload(
      bytes: Uint8List.fromList(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
        ),
      ),
      filename: 'photo.png',
      mimeType: 'image/png',
    );
  }

  @override
  Future<void> startAudioRecording() async {
    recordingStarts++;
  }

  @override
  Future<WisperBotUpload?> stopAudioRecording() async {
    recordingStops++;
    return WisperBotUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      filename: 'voice.wav',
      mimeType: 'audio/wav',
    );
  }

  @override
  Future<void> cancelAudioRecording() async {
    recordingCancels++;
  }
}
