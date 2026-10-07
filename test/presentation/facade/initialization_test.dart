import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import '../../support/fixtures/widget_api_fixtures.dart';

void main() {
  setUp(WisperBotChat.shutdown);
  tearDown(WisperBotChat.shutdown);

  test('same-option initialization is idempotent', () async {
    await WisperBotChat.initialize(
      widgetKey: 'same-config',
      enableOneSignal: false,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
    );
    await WisperBotChat.initialize(
      widgetKey: 'same-config',
      enableOneSignal: false,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
    );

    expect(
      () => WisperBotChat.initialize(
        widgetKey: 'different-config',
        enableOneSignal: false,
        requireNotificationPermission: false,
        registerVisitorOnAppLaunch: false,
      ),
      throwsA(isA<WisperBotException>()),
    );
  });

  testWidgets('default startup registration runs exactly once', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'startup-registration',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        requireNotificationPermission: false,
        sessionStore: const _NoopSessionStore(),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
      await tester.pump();
    }, () => client);

    expect(bodies, hasLength(1));
    expect(bodies.single['key'], 'startup-registration');
  });

  testWidgets('disabled startup registration waits until chat is used',
      (tester) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'deferred-registration',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        requireNotificationPermission: false,
        registerVisitorOnAppLaunch: false,
        sessionStore: const _NoopSessionStore(),
      );
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: WisperBotChatLauncher()),
      ));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(
          requests.single.url.path, '/widgets/chat/deferred-registration.js');

      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last.method, 'POST');
      expect(requests.last.url.path, '/widget/v1/session');
    }, () => client);
  });

  testWidgets('identify before the first frame avoids anonymous registration',
      (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'identified-registration',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        requireNotificationPermission: false,
        sessionStore: const _NoopSessionStore(),
      );
      await WisperBotChat.identify(
        const WisperBotUser(externalId: 'customer-1', name: 'Jane'),
      );
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pumpAndSettle();
    }, () => client);

    expect(bodies, hasLength(1));
    expect(bodies.single['external_id'], 'customer-1');
    expect(bodies.single['name'], 'Jane');
  });

  testWidgets('default UI fails fast before initialization', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () {},
          child: const Text('Ready'),
        ),
      ),
    ));
    final context = tester.element(find.text('Ready'));

    expect(
      () => WisperBotChat.open(context),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.configuration,
        ),
      ),
    );
  });

  test('headless client accepts configuration directly', () async {
    final client = WisperBotClient(
      widgetKey: 'headless-runtime',
      enableOneSignal: false,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
      sessionStore: const _NoopSessionStore(),
    );
    final controller = WisperBotChatController(client: client);

    expect(controller.user, isNull);

    await controller.dispose();
    await client.close();
  });

  testWidgets('global views reuse and do not dispose the shared controller',
      (tester) async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'shared-controller',
        apiBaseUrl: 'https://chat.example.com',
        enableOneSignal: false,
        requireNotificationPermission: false,
        registerVisitorOnAppLaunch: false,
        sessionStore: const _NoopSessionStore(),
      );
      final shared = WisperBotChat.requireDefaultController();

      await tester.pumpWidget(MaterialApp(home: WisperBotChat.view()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      await tester.pump();
      await tester.pumpWidget(MaterialApp(home: WisperBotChat.view()));
      await tester.pumpAndSettle();

      expect(WisperBotChat.requireDefaultController(), same(shared));
      expect(requests, 1);
    }, () => client);
  });
}

final class _NoopSessionStore implements WisperBotSessionStore {
  const _NoopSessionStore();

  @override
  Future<void> delete(String namespace) async {}

  @override
  Future<WisperBotStoredSession?> read(String namespace) async => null;

  @override
  Future<void> write(String namespace, WisperBotStoredSession session) async {}
}
