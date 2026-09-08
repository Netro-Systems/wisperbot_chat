part of 'chat_widgets_test.dart';

void registerLauncherTests(WisperBotConfig config) {
  testWidgets('launcher has an accessible 48dp target and server alignment', (tester) async {
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
    testWidgets('launcher zoom stays fixed with $alignmentName alignment', (tester) async {
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

  testWidgets('custom launcher builder retains loading-state control', (tester) async {
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

  testWidgets('launcher skips its entrance transition for reduced motion', (tester) async {
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

  testWidgets('remote brand assets use contained web-widget sizing', (tester) async {
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
}
