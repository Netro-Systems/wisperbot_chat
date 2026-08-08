part of 'chat_widgets_test.dart';

void registerComposerHandoffTests(WisperBotConfig config) {
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
    final uploadedContentTypes = <String>[];
    final uploadedBodies = <List<int>>[];
    final runtime = _runtime(
      mediaConfig,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          uploadedContentTypes.add(request.headers['content-type'] ?? '');
          uploadedBodies.add(request.bodyBytes);
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
    expect(uploadedContentTypes.single, startsWith('multipart/form-data;'));
    final imageBody = utf8.decode(uploadedBodies.single, allowMalformed: true);
    expect(imageBody, contains('name="key"'));
    expect(imageBody, contains('test-widget'));
    expect(imageBody, contains('name="type"'));
    expect(imageBody, contains('image'));
    expect(imageBody, contains('name="attachment"; filename="photo.png"'));
    expect(preview, findsNothing);

    await tester.tap(find.byTooltip('Record voice message'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.recordingStarts, 1);
    expect(
      find.bySemanticsLabel(RegExp('Recording voice message')),
      findsOneWidget,
    );
    expect(find.byTooltip('Stop voice recording'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop voice recording'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.recordingStops, 1);
    final audioPreview = find.byKey(
      const ValueKey<String>('wisperbot-audio-preview'),
    );
    expect(audioPreview, findsOneWidget);
    expect(uploadCount, 1);

    await tester.tap(
      find.descendant(of: audioPreview, matching: find.text('Send')),
    );
    await tester.pumpAndSettle();
    expect(uploadCount, 2);
    expect(uploadedContentTypes.last, startsWith('multipart/form-data;'));
    final audioBody = utf8.decode(uploadedBodies.last, allowMalformed: true);
    expect(audioBody, contains('audio'));
    expect(audioBody, contains('name="attachment"; filename="voice.wav"'));
    expect(find.text('Recording… tap stop to preview'), findsNothing);
    expect(audioPreview, findsNothing);

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
}
