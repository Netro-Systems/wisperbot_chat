part of 'chat_widgets_test.dart';

void registerPresentationLayoutTests(WisperBotConfig config) {
  testWidgets('full-screen chat can use light status-bar icons',
      (tester) async {
    const lightStatusConfig = WisperBotConfig(
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      enableOneSignal: false,
      lightStatusBarIcons: true,
    );
    final runtime = _runtime(
      lightStatusConfig,
      MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200),
      ),
    );

    await tester.pumpWidget(_app(WisperBotChatScreen(
      config: lightStatusConfig,
      controller: runtime.controller,
    )));
    await tester.pump();

    final overlay = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find
          .descendant(
            of: find.byType(WisperBotChatScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          )
          .first,
    );
    expect(overlay.value.statusBarIconBrightness, Brightness.light);
    expect(overlay.value.statusBarBrightness, Brightness.dark);
    expect(overlay.value.statusBarColor, Colors.transparent);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('composer shares a row and expands on focus', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runtime = _runtime(
      config,
      MockClient(
          (_) async => http.Response(jsonEncode(sessionResponse()), 200)),
    );
    await tester.pumpWidget(_app(WisperBotChatView(
      config: config,
      controller: runtime.controller,
    )));
    await tester.pump();
    await tester.pump();

    final field = find.byType(TextField);
    final attachment = find.byTooltip('Attach file');
    final microphone = find.byTooltip('Record voice message');
    final send = find.byTooltip('Send message');
    final sendIcon = find.descendant(of: send, matching: find.byType(Image));
    final disabledSendIconColor = tester.widget<Image>(sendIcon).color;
    final compactSize = tester.getSize(field);
    expect(compactSize.height, closeTo(42, 1));
    expect(tester.getSize(attachment).height, closeTo(compactSize.height, 1));
    expect(tester.getSize(microphone).height, closeTo(compactSize.height, 1));
    expect(tester.getSize(send).height, closeTo(compactSize.height, 1));
    expect(tester.getBottomLeft(attachment).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));
    expect(tester.getBottomLeft(send).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, greaterThan(compactSize.width));
    expect(tester.getSize(field).height, closeTo(compactSize.height, 1));
    expect(tester.getBottomLeft(attachment).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));
    expect(tester.getBottomLeft(send).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));
    await tester.enterText(field, 'First line\nSecond line\nThird line');
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(sendIcon).color, isNot(disabledSendIconColor));
    expect(tester.widget<Image>(sendIcon).color, const Color(0xFFFFFFFF));
    expect(tester.getSize(field).height, greaterThan(compactSize.height));
    expect(tester.getBottomLeft(attachment).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));
    expect(tester.getBottomLeft(send).dy,
        closeTo(tester.getBottomLeft(field).dy, 1));
    expect(tester.takeException(), isNull);

    final focusNode = tester.widget<TextField>(field).focusNode!;
    focusNode.unfocus();
    await tester.pumpAndSettle();
    expect(tester.getSize(field).width, closeTo(compactSize.width, 1));
    expect(tester.widget<TextField>(field).controller!.text,
        'First line\nSecond line\nThird line');
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
      enableOneSignal: false,
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
      enableOneSignal: false,
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
