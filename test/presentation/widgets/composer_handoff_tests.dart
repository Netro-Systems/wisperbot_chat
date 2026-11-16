part of 'chat_widgets_test.dart';

void registerComposerHandoffTests(WisperBotConfig config) {
  testWidgets('gallery sends removable drafts in one photo group',
      (tester) async {
    final previousPicker = ImagePickerPlatform.instance;
    final gallery = _GalleryTestPicker();
    ImagePickerPlatform.instance = gallery;
    addTearDown(() => ImagePickerPlatform.instance = previousPicker);

    final uploads = <String>[];
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(jsonEncode(sessionResponse()), 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          final body = utf8.decode(request.bodyBytes, allowMalformed: true);
          uploads.add(body);
          if (uploads.length == 2) throw http.ClientException('Lost response');
          return http.Response(
            jsonEncode(<String, Object?>{
              'message': message(
                id: uploads.length,
                role: 'visitor',
                type: 'image',
                body: uploads.length == 1 ? 'See these photos' : '',
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

    await tester
        .pumpWidget(_app(WisperBotChatView(controller: runtime.controller)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(gallery.limit, 6);
    expect(find.byTooltip('Discard image 4'), findsOneWidget);
    await tester.tap(find.byTooltip('Discard image 2'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Discard image 4'), findsNothing);

    await tester.enterText(find.byType(TextField), 'See these photos');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(uploads, hasLength(2));
    expect(uploads[0], contains('filename="first.png"'));
    expect(uploads[1], contains('filename="unconfirmed.png"'));
    expect(find.text('last.png'), findsOneWidget);
    expect(runtime.controller.state.messages.last.status,
        WisperBotMessageStatus.unconfirmed);

    await tester.tap(find.text('Send remaining'));
    await tester.pumpAndSettle();
    expect(uploads, hasLength(3));
    expect(uploads[2], contains('filename="last.png"'));
    final groupField = RegExp(r'name="photo_group_id"\r\n\r\n([\w-]+)');
    final groupIds =
        uploads.map((body) => groupField.firstMatch(body)?.group(1));
    expect(
        groupIds.first,
        matches(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$'));
    expect(groupIds, everyElement(groupIds.first));
    expect(uploads.where((body) => body.contains('See these photos')),
        hasLength(1));
    expect(find.byKey(const ValueKey<String>('wisperbot-image-preview')),
        findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final presentation in WisperBotPresentation.values) {
      testWidgets(
          'microphone denial shows Settings only on retry on $platform in $presentation',
          (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final messenger = tester.binding.defaultBinaryMessenger;
        const recorderChannel = MethodChannel('com.llfbandit.record/messages');
        const settingsChannel =
            MethodChannel('com.spencerccf.app_settings/methods');
        final recorderCalls = <String>[];
        final permissionRequests = <bool>[];
        final settingsCalls = <MethodCall>[];
        messenger.setMockMethodCallHandler(recorderChannel, (call) async {
          recorderCalls.add(call.method);
          if (call.method == 'create') {
            final id = (call.arguments as Map)['recorderId'];
            final events = MethodChannel('com.llfbandit.record/events/$id');
            messenger.setMockMethodCallHandler(events, (_) async => null);
            addTearDown(() => messenger.setMockMethodCallHandler(events, null));
          }
          if (call.method == 'hasPermission') {
            permissionRequests.add((call.arguments as Map)['request'] as bool);
            return false;
          }
          return null;
        });
        messenger.setMockMethodCallHandler(settingsChannel, (call) async {
          settingsCalls.add(call);
          return null;
        });
        addTearDown(() {
          messenger.setMockMethodCallHandler(recorderChannel, null);
          messenger.setMockMethodCallHandler(settingsChannel, null);
        });
        final runtime = _runtime(
            config,
            MockClient((request) async => http.Response(
                jsonEncode(request.url.path.endsWith('/session')
                    ? sessionResponse()
                    : pollResponse()),
                200)));
        await tester.pumpWidget(_app(Builder(
            builder: (context) => TextButton(
                  onPressed: () => WisperBotChat.open(context,
                      controller: runtime.controller,
                      presentation: presentation),
                  child: const Text('Open chat'),
                ))));
        await tester.tap(find.text('Open chat'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Record voice message'));
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(find.byTooltip('Cancel recording'), findsNothing);
        expect(permissionRequests, [true]);
        await tester.tap(find.byTooltip('Record voice message'));
        await tester.pumpAndSettle();
        expect(
            find.text(
                'Enable microphone access in Settings to record voice messages.'),
            findsOneWidget);
        expect(find.widgetWithText(SnackBarAction, 'Settings').hitTestable(),
            findsOneWidget);
        expect(recorderCalls, contains('hasPermission'));
        expect(recorderCalls, isNot(contains('startStream')));
        expect(find.byTooltip('Cancel recording'), findsNothing);
        await tester.tap(find.text('Settings'));
        await tester.pumpAndSettle();
        expect(settingsCalls.single.method, 'openSettings');
        expect((settingsCalls.single.arguments as Map)['type'], 'settings');
        await tester.tap(find.byTooltip('Record voice message'));
        await tester.pumpAndSettle();
        expect(recorderCalls.where((call) => call == 'hasPermission'),
            hasLength(3));
        expect(permissionRequests, [true, false, false]);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(WisperBotChatView))).pop();
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await runtime.dispose();
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }

  testWidgets('default composer picks images and records voice through adapter',
      (tester) async {
    final mediaAdapter = _FakeMediaAdapter();
    final mediaConfig = WisperBotConfig(
      requireNotificationPermission: false,
      widgetKey: 'test-widget',
      apiBaseUrl: 'https://chat.example.com',
      mediaAdapter: mediaAdapter,
      enablePushNotifications: false,
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
          final type = switch (uploadCount) {
            1 => 'image',
            2 => 'document',
            _ => 'audio',
          };
          return http.Response(
            jsonEncode(<String, Object?>{
              'message': message(
                id: uploadCount,
                role: 'visitor',
                type: type,
                body: switch (type) {
                  'image' => 'Image attachment',
                  'document' => 'document.pdf',
                  _ => 'Voice message',
                },
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
        controller: runtime.controller,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Attach file'), findsOneWidget);
    expect(find.byTooltip('Record voice message'), findsOneWidget);

    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    await tester.tap(find.text('Gallery'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.imagePicks, 1);
    final preview = find.byKey(
      const ValueKey<String>('wisperbot-image-preview'),
    );
    expect(preview, findsOneWidget);

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(uploadCount, 1);
    expect(uploadedContentTypes.first, startsWith('multipart/form-data;'));
    final imageBody = utf8.decode(uploadedBodies.first, allowMalformed: true);
    expect(imageBody, contains('name="key"'));
    expect(imageBody, contains('test-widget'));
    expect(imageBody, contains('name="type"'));
    expect(imageBody, contains('image'));
    expect(imageBody, contains('name="attachment"; filename="photo.png"'));
    expect(preview, findsNothing);

    // Pick and send Document
    await tester.tap(find.byTooltip('Attach file'));
    await tester.pumpAndSettle();
    expect(find.byType(AttachmentPickerSheet), findsOneWidget);
    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();
    expect(mediaAdapter.documentPicks, 1);
    final docPreview = find.byKey(
      const ValueKey<String>('wisperbot-file-preview'),
    );
    expect(docPreview, findsOneWidget);
    expect(find.text('document.pdf'), findsOneWidget);

    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(uploadCount, 2);
    expect(uploadedContentTypes[1], startsWith('multipart/form-data;'));
    final docBody = utf8.decode(uploadedBodies[1], allowMalformed: true);
    expect(docBody, contains('name="type"'));
    expect(docBody, contains('document'));
    expect(docBody, contains('name="attachment"; filename="document.pdf"'));
    expect(docPreview, findsNothing);

    // Record and send Audio
    await tester.tap(find.byTooltip('Record voice message'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mediaAdapter.recordingStarts, 1);
    expect(
      find.bySemanticsLabel(RegExp('Recording voice message')),
      findsOneWidget,
    );
    expect(find.byTooltip('Send voice message'), findsOneWidget);
    expect(find.byTooltip('Cancel recording'), findsOneWidget);

    await tester.tap(find.byTooltip('Send voice message'));
    await tester.pump(const Duration(milliseconds: 120));
    expect(mediaAdapter.recordingStops, 1);
    expect(uploadCount, 3);
    expect(uploadedContentTypes.last, startsWith('multipart/form-data;'));
    final audioBody = utf8.decode(uploadedBodies.last, allowMalformed: true);
    expect(audioBody, contains('audio'));
    expect(audioBody, contains('name="attachment"; filename="voice.wav"'));
    expect(find.byTooltip('Send voice message'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('wisperbot-audio-preview')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  for (final status in ['waiting', 'connected']) {
    testWidgets('handoff keeps its bar and size when $status', (tester) async {
      var handoffCalls = 0;
      final handoffResponse = Completer<http.Response>();
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
            return handoffResponse.future;
          }
          return http.Response(jsonEncode(pollResponse()), 200);
        }),
      );

      await tester.pumpWidget(_app(
        WisperBotChatView(controller: runtime.controller),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Need a person?'), findsOneWidget);
      expect(find.text('Talk to an agent'), findsOneWidget);
      expect(
        tester.getBottomLeft(find.text('Talk to an agent')).dy,
        lessThan(tester.getTopLeft(find.byType(RefreshIndicator)).dy),
      );
      final timelineTop = tester.getTopLeft(find.byType(RefreshIndicator));
      await tester.tap(find.text('Talk to an agent'));
      await tester.pump();
      expect(find.text('Requesting human support…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.getTopLeft(find.byType(RefreshIndicator)), timelineTop);
      handoffResponse.complete(http.Response(
          jsonEncode({
            'handoff': {
              'enabled': status == 'waiting',
              'eligible': false,
              'status': status
            },
          }),
          200));
      await tester.pump();
      await tester.pump();
      expect(
          find.text(status == 'waiting'
              ? 'Waiting for an agent to join…'
              : 'An agent joined this chat'),
          findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.getTopLeft(find.byType(RefreshIndicator)), timelineTop);

      expect(handoffCalls, 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.dispose();
    });
  }

  testWidgets('joined agent name appears without a loader', (tester) async {
    final response = sessionResponse();
    response['handoff'] = {
      'enabled': true,
      'eligible': false,
      'status': 'connected',
      'agent': {'name': 'Rahim'},
    };
    final runtime = _runtime(config,
        MockClient((_) async => http.Response(jsonEncode(response), 200)));
    await tester.pumpWidget(_app(
      WisperBotChatView(controller: runtime.controller),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.text('Rahim joined this chat'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
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
      WisperBotChatView(controller: runtime.controller),
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

class _GalleryTestPicker extends ImagePickerPlatform {
  int? limit;

  @override
  Future<List<XFile>> getMultiImageWithOptions({
    MultiImagePickerOptions options = const MultiImagePickerOptions(),
  }) async {
    limit = options.limit;
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=',
    );
    return <XFile>[
      for (final name in ['first', 'discarded', 'unconfirmed', 'last'])
        XFile.fromData(png, path: '/$name.png', name: '$name.png'),
    ];
  }
}
