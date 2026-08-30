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
      find.bySemanticsLabel('Send message'),
    );
    expect(sendButtonSize.width, greaterThanOrEqualTo(48));
    expect(sendButtonSize.height, greaterThanOrEqualTo(48));

    await tester.enterText(find.byType(TextField), 'Hello SDK');
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Send message'));
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

  testWidgets('ready view opens at the latest message', (tester) async {
    final messages = List<Map<String, Object?>>.generate(40, (index) {
      final id = index + 1;
      return message(
        id: id,
        body: id == 40 ? 'Latest message 40' : 'Older message $id',
      );
    });
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(sessionResponse(messages: messages)),
            200,
          );
        }
        return http.Response('{"ok":true}', 200);
      }),
    );

    await tester.pumpWidget(_app(
      SizedBox(
        height: 360,
        child:
            WisperBotChatView(config: config, controller: runtime.controller),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.text('Latest message 40'), findsOneWidget);
    expect(find.text('Older message 1'), findsNothing);

    final listView = tester.widget<ListView>(find.byType(ListView));
    final position = listView.controller!.position;
    expect(position.pixels, position.minScrollExtent);

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
    await tester.tap(find.bySemanticsLabel('Send message'));
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
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      runtime.controller.state.messages.single.status,
      WisperBotMessageStatus.sent,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('shows focused double checkmark for read/seen outbound message',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(sessionResponse(messages: <Map<String, Object?>>[
              message(
                id: 1,
                role: 'visitor',
                body: 'Hello seen message',
                sentBy: 'human',
              )..['status'] = 'seen',
            ])),
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

    final iconFinder = find.byIcon(Icons.done_all);
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.color, equals(const Color(0xFF53BDEB)));
    expect(runtime.controller.state.messages.single.isSeen, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('shows double checkmark for delivered outbound message',
      (tester) async {
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(sessionResponse(messages: <Map<String, Object?>>[
              message(
                id: 1,
                role: 'visitor',
                body: 'Delivered message',
                sentBy: 'human',
              )..['status'] = 'delivered',
            ])),
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

    final iconFinder = find.byIcon(Icons.done_all);
    expect(iconFinder, findsOneWidget);
    final icon = tester.widget<Icon>(iconFinder);
    expect(icon.color, isNot(equals(const Color(0xFF53BDEB))));
    expect(runtime.controller.state.messages.single.isDelivered, isTrue);
    expect(runtime.controller.state.messages.single.isSeen, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('pending image upload renders local timeline preview',
      (tester) async {
    final sendResponse = Completer<http.Response>();
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      polling: config.polling,
      mediaAdapter: mediaAdapter,
      enableOneSignal: false,
    );
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          return sendResponse.future;
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
    await tester.tap(find.bySemanticsLabel('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(mediaAdapter.imagePicks, 1);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-local-image-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-image-preview')),
      findsNothing,
    );
    expect(runtime.controller.state.messages.single.status,
        WisperBotMessageStatus.pending);

    sendResponse.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 1,
            role: 'visitor',
            type: 'image',
            body: 'Image attachment',
            sentBy: 'human',
            attachmentUrl: 'https://cdn.example.com/photo.png',
            filename: 'photo.png',
            mimeType: 'image/png',
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

    expect(runtime.controller.state.messages.single.status,
        WisperBotMessageStatus.sent);
    expect(runtime.controller.state.messages.single.localUpload?.filename,
        'photo.png');
    expect(
      find.byKey(const ValueKey<String>('wisperbot-local-image-preview')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('failed image upload keeps local preview with error icon',
      (tester) async {
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      polling: config.polling,
      mediaAdapter: mediaAdapter,
      enableOneSignal: false,
    );
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          throw http.ClientException('connection dropped after upload');
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
    await tester.tap(find.bySemanticsLabel('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Send message'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byKey(const ValueKey<String>('wisperbot-local-image-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-local-image-error')),
      findsOneWidget,
    );
    expect(runtime.controller.state.messages.single.status,
        WisperBotMessageStatus.unconfirmed);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets(
      'tapping image preview opens full screen viewer with InteractiveViewer',
      (tester) async {
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      polling: config.polling,
      mediaAdapter: mediaAdapter,
      enableOneSignal: false,
    );
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(sessionResponse(
              messages: <Map<String, Object?>>[
                message(
                  id: 1,
                  role: 'agent',
                  type: 'image',
                  body: 'Screenshot',
                  sentBy: 'bot',
                  attachmentUrl: 'https://cdn.example.com/screenshot.png',
                  filename: 'screenshot.png',
                  mimeType: 'image/png',
                ),
              ],
            )),
            200,
          );
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
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

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-remote-image-preview')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('wisperbot-remote-image-preview')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('screenshot.png'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('pending audio upload renders local timeline preview',
      (tester) async {
    final sendResponse = Completer<http.Response>();
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      polling: config.polling,
      mediaAdapter: mediaAdapter,
      enableOneSignal: false,
    );
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          return sendResponse.future;
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
    await tester.tap(find.byTooltip('Record voice message'));
    await tester.pump(const Duration(milliseconds: 120));
    await tester.tap(find.byTooltip('Send voice message'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(mediaAdapter.recordingStarts, 1);
    expect(mediaAdapter.recordingStops, 1);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-local-audio-preview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-audio-preview')),
      findsNothing,
    );
    expect(find.byTooltip('Send voice message'), findsNothing);
    expect(runtime.controller.state.messages.single.status,
        WisperBotMessageStatus.pending);

    sendResponse.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 1,
            role: 'visitor',
            type: 'audio',
            body: 'Voice message',
            sentBy: 'human',
            attachmentUrl: 'https://cdn.example.com/voice.wav',
            filename: 'voice.wav',
            mimeType: 'audio/wav',
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

    expect(runtime.controller.state.messages.single.status,
        WisperBotMessageStatus.sent);
    expect(runtime.controller.state.messages.single.localUpload?.filename,
        'voice.wav');

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

  testWidgets('partial pre-chat only shows missing fields and includes active user',
      (tester) async {
    var calls = 0;
    Map<String, dynamic>? submitted;
    final partialConfig = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      enableOneSignal: false,
      user: const WisperBotUser(name: 'Jane Doe'),
    );
    final runtime = _runtime(
      partialConfig,
      MockClient((request) async {
        calls++;
        if (calls == 2) {
          submitted = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return http.Response(
          jsonEncode(sessionResponse(requirePreChat: true)),
          200,
        );
      }),
    );

    await tester.pumpWidget(_app(
      WisperBotChatView(
        config: partialConfig,
        controller: runtime.controller,
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('wisperbot-prechat-name')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('wisperbot-prechat-email')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey<String>('wisperbot-prechat-email')),
      'jane@example.com',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('wisperbot-prechat-submit')),
    );
    await tester.pumpAndSettle();

    expect(submitted?['name'], 'Jane Doe');
    expect(submitted?['email'], 'jane@example.com');
    expect(find.byTooltip('Send message'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}
