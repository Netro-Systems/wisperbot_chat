part of 'chat_widgets_test.dart';

void registerViewStateTests(WisperBotConfig config) {
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
    expect(tester.getSize(appBarLine).height, 1);
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
    expect(find.text('Sent'), findsNothing);
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

  testWidgets('normal message delivery does not show sending or sent labels',
      (tester) async {
    final sendResponse = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        return sendResponse.future;
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'No delayed status');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No delayed status'), findsOneWidget);
    expect(find.text('Sending'), findsNothing);
    expect(find.text('Sent'), findsNothing);

    sendResponse.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 1,
            role: 'visitor',
            body: 'No delayed status',
            sentBy: 'human',
          ),
          'handoff': <String, Object?>{
            'enabled': true,
            'eligible': false,
            'status': 'bot',
          },
        }),
        200,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Sending'), findsNothing);
    expect(find.text('Sent'), findsNothing);
    expect(
      runtime.controller.state.messages.single.status,
      WisperBotMessageStatus.sent,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('audio messages render a playback control', (tester) async {
    final mediaRequestHeaders = <Map<String, String>>[];
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/voice.m4a')) {
          mediaRequestHeaders.add(request.headers);
          return http.Response.bytes(
            Uint8List.fromList(<int>[1, 2, 3, 4]),
            200,
            headers: <String, String>{'content-type': 'audio/mp4'},
          );
        }
        return http.Response(
          jsonEncode(sessionResponse(messages: <Map<String, Object?>>[
            message(
              id: 1,
              role: 'visitor',
              type: 'audio',
              body: 'Voice message',
              sentBy: 'human',
              attachmentUrl: 'https://chat.example.com/voice.m4a',
              filename: 'voice.m4a',
              mimeType: 'audio/mp4',
            ),
          ])),
          200,
        );
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Play voice message'), findsOneWidget);
    expect(find.text('Voice message'), findsNothing);
    expect(mediaRequestHeaders.single['X-Widget-Token'], 'token-1');
    expect(mediaRequestHeaders.single['Accept'], 'audio/*,*/*');

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('required pre-chat collects fields before showing composer',
      (tester) async {
    var calls = 0;
    Map<String, dynamic>? submitted;
    String? submittedToken;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        calls++;
        if (calls == 2) {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
          submittedToken = request.headers['X-Widget-Token'];
        }
        return http.Response(
          jsonEncode(sessionResponse(requirePreChat: true)),
          200,
        );
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(config: config, controller: runtime.controller),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('wisperbot-prechat-name')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-prechat-email')),
      findsOneWidget,
    );
    expect(find.byTooltip('Send message'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('wisperbot-prechat-name')),
      'Jane Doe',
    );
    await tester.enterText(
      find.byKey(const ValueKey<String>('wisperbot-prechat-email')),
      'jane@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wisperbot-prechat-submit')),
    );
    await tester.pumpAndSettle();

    expect(submittedToken, 'token-1');
    expect(submitted?['visitor_id'], 'visitor-1');
    expect(submitted?['name'], 'Jane Doe');
    expect(submitted?['email'], 'jane@example.com');
    expect(find.byTooltip('Send message'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}
