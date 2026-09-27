part of 'chat_widgets_test.dart';

void registerStarterQuestionsTests(WisperBotConfig config) {
  const first = <String, Object?>{
    'id': 'sq_hours',
    'label': 'What are your opening hours?',
  };
  const second = <String, Object?>{
    'id': 'sq_refunds',
    'label': 'What is your refund policy?',
  };

  testWidgets(
      'renders ordered questions below welcome, sends label, polls, and keeps them visible',
      (tester) async {
    Map<String, dynamic>? sentBody;
    var immediatePolls = 0;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(
              sessionResponse(
                aiEnabled: false,
                starterQuestions: const [first, second],
                messages: <Map<String, Object?>>[
                  message(id: 1, body: 'An earlier answer'),
                ],
              ),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, Object?>{
              'message': message(
                id: 2,
                role: 'visitor',
                body: first['label']! as String,
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
        if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
          immediatePolls++;
          expect(request.url.queryParameters['after'], '2');
          return http.Response(
            jsonEncode(
              pollResponse(
                messages: <Map<String, Object?>>[
                  message(id: 3, body: 'Monday through Friday.'),
                ],
              ),
            ),
            200,
          );
        }
        if (request.url.path.endsWith('/read')) {
          return http.Response('{"ok":true}', 200);
        }
        throw StateError(
            'Unexpected request: ${request.method} ${request.url}');
      }),
    );

    await tester.pumpWidget(
      _app(WisperBotChatView(config: config, controller: runtime.controller)),
    );
    await tester.pumpAndSettle();

    final welcome = find.text('Welcome to the test chat');
    final firstLabel = find.text(first['label']! as String);
    final secondLabel = find.text(second['label']! as String);
    final messageLabel = find.text('An earlier answer');
    expect(find.bySemanticsLabel('Common questions'), findsOneWidget);
    expect(firstLabel, findsOneWidget);
    expect(secondLabel, findsOneWidget);
    expect(tester.getTopLeft(welcome).dy,
        lessThan(tester.getTopLeft(firstLabel).dy));
    expect(tester.getTopLeft(firstLabel).dy,
        lessThan(tester.getTopLeft(messageLabel).dy));
    expect(tester.getTopLeft(secondLabel).dy,
        lessThan(tester.getTopLeft(messageLabel).dy));

    await tester.tap(find.byKey(const ValueKey<String>('sq_hours')));
    await tester.pumpAndSettle();

    expect(sentBody?['message'], first['label']);
    expect(sentBody?['message'], isNot(first['id']));
    expect(immediatePolls, 1);
    expect(find.text('Monday through Friday.'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sq_hours')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('sq_refunds')), findsOneWidget);
    expect(
      runtime.controller.state.messages.where((item) => item.serverId == 3),
      hasLength(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('disables questions while a text send is in flight',
      (tester) async {
    final releaseSend = Completer<http.Response>();
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          return http.Response(
            jsonEncode(sessionResponse(starterQuestions: const [first])),
            200,
          );
        }
        if (request.url.path.endsWith('/typing')) {
          return http.Response('{"ok":true}', 200);
        }
        if (request.method == 'POST' &&
            request.url.path.endsWith('/messages')) {
          return releaseSend.future;
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode(pollResponse()), 200);
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await tester.pumpWidget(
      _app(WisperBotChatView(config: config, controller: runtime.controller)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('sq_hours')));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('sq_hours')),
          )
          .onPressed,
      isNull,
    );

    releaseSend.complete(
      http.Response(
        jsonEncode(<String, Object?>{
          'message': message(
            id: 1,
            role: 'visitor',
            body: first['label']! as String,
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
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('sq_hours')),
          )
          .onPressed,
      isNotNull,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('pre-chat and active handoff expose disabled question buttons',
      (tester) async {
    for (final scenario in <({bool preChat, String status})>[
      (preChat: true, status: 'bot'),
      (preChat: false, status: 'waiting'),
      (preChat: false, status: 'connected'),
    ]) {
      final runtime = _runtime(
        config,
        MockClient((request) async => http.Response(
              jsonEncode(
                sessionResponse(
                  requirePreChat: scenario.preChat,
                  handoffStatus: scenario.status,
                  starterQuestions: const [first],
                ),
              ),
              200,
            )),
      );
      await tester.pumpWidget(
        _app(WisperBotChatView(config: config, controller: runtime.controller)),
      );
      await tester.pump();
      await tester.pump();
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey<String>('sq_hours')),
            )
            .onPressed,
        isNull,
        reason: 'preChat=${scenario.preChat}, status=${scenario.status}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await runtime.dispose();
    }
  });

  testWidgets('bot handoff keeps starter questions enabled', (tester) async {
    final runtime = _runtime(
      config,
      MockClient((request) async => http.Response(
            jsonEncode(
              sessionResponse(
                handoffStatus: 'bot',
                starterQuestions: const [first],
              ),
            ),
            200,
          )),
    );
    await tester.pumpWidget(
      _app(WisperBotChatView(config: config, controller: runtime.controller)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const ValueKey<String>('sq_hours')),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });

  testWidgets('a new session replaces or removes the starter-question list',
      (tester) async {
    var sessions = 0;
    final runtime = _runtime(
      config,
      MockClient((request) async {
        if (request.url.path.endsWith('/session')) {
          sessions++;
          return http.Response(
            jsonEncode(
              sessionResponse(
                starterQuestions: sessions == 1
                    ? const [first]
                    : sessions == 2
                        ? const [second]
                        : const <Map<String, Object?>>[],
              ),
            ),
            200,
          );
        }
        throw StateError('Unexpected request: ${request.url}');
      }),
    );
    await tester.pumpWidget(
      _app(WisperBotChatView(config: config, controller: runtime.controller)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('sq_hours')), findsOneWidget);

    await runtime.controller.resetSession();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey<String>('sq_hours')), findsNothing);
    expect(find.byKey(const ValueKey<String>('sq_refunds')), findsOneWidget);

    await runtime.controller.resetSession();
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Common questions'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.dispose();
  });
}
