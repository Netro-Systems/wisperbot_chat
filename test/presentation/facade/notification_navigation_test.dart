import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/widget_onesignal_service.dart';

import '../../support/fixtures/widget_api_fixtures.dart';

void main() {
  setUp(() async {
    await WisperBotChat.shutdown();
    WidgetOneSignalService.instance.resetForTesting();
    WidgetOneSignalService.instance.setPushTokenOverride('test-token');
  });

  tearDown(() async {
    await WisperBotChat.shutdown();
    WidgetOneSignalService.instance.resetForTesting();
  });

  Future<GlobalKey<NavigatorState>> mountHost(
    WidgetTester tester, {
    void Function(Map<String, dynamic>)? onNotificationTapped,
    void Function(Map<String, dynamic>)? onForegroundNotification,
  }) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await WisperBotChat.initialize(
      widgetKey: 'notification-test-widget',
      apiBaseUrl: 'https://chat.example.com',
      enableOneSignal: false,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
      sessionStore: const _NoopSessionStore(),
      navigatorKey: navigatorKey,
      onNotificationTapped: onNotificationTapped,
      onForegroundNotification: onForegroundNotification,
    );
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(
        body: Center(child: Text('Home Screen')),
      ),
    ));
    return navigatorKey;
  }

  testWidgets('notification click opens the shared chat runtime',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(sessionResponse()), 200),
    );

    await http.runWithClient(() async {
      await mountHost(tester);
      await tester.pumpAndSettle();

      WidgetOneSignalService.instance.simulateNotificationClick({
        'conversation_id': 12345,
        'title': 'Support Agent',
        'body': 'Hello! How can I help you today?',
      });

      await tester.pumpAndSettle();
      expect(find.byType(WisperBotChatScreen), findsOneWidget);
      expect(find.text('Test support'), findsOneWidget);
    }, () => client);
  });

  testWidgets('cold-start notification click is preserved until mounting',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(sessionResponse()), 200),
    );

    await http.runWithClient(() async {
      WidgetOneSignalService.instance.simulateNotificationClick({
        'conversation_id': 999,
        'body': 'Your order has been updated.',
      });

      await mountHost(tester);
      await tester.pumpAndSettle();
      expect(find.byType(WisperBotChatScreen), findsOneWidget);
    }, () => client);
  });

  testWidgets('foreground messages do not display an SDK SnackBar',
      (tester) async {
    await mountHost(tester);
    WidgetOneSignalService.instance.simulateForegroundNotification({
      'body': 'We replied to your message.',
    });
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('We replied to your message.'), findsNothing);
  });

  testWidgets('custom notification callback intercepts click', (tester) async {
    Map<String, dynamic>? intercepted;
    await mountHost(
      tester,
      onNotificationTapped: (payload) => intercepted = payload,
    );

    WidgetOneSignalService.instance.simulateNotificationClick({
      'conversation_id': 555,
      'body': 'Custom Body',
    });
    await tester.pump();

    expect(intercepted?['conversation_id'], 555);
    expect(find.byType(WisperBotChatScreen), findsNothing);
  });

  testWidgets('custom foreground callback receives the payload',
      (tester) async {
    Map<String, dynamic>? intercepted;
    await mountHost(
      tester,
      onForegroundNotification: (payload) => intercepted = payload,
    );

    WidgetOneSignalService.instance.simulateForegroundNotification({
      'conversation_id': 777,
      'body': 'Foreground payload test',
    });
    await tester.pump();

    expect(intercepted?['conversation_id'], 777);
    expect(find.text('Foreground payload test'), findsNothing);
  });

  testWidgets('repeated initialization does not duplicate listeners',
      (tester) async {
    var callbacks = 0;
    final navigatorKey = await mountHost(
      tester,
      onForegroundNotification: (_) => callbacks++,
    );
    await WisperBotChat.initialize(
      widgetKey: 'notification-test-widget',
      apiBaseUrl: 'https://chat.example.com',
      enableOneSignal: false,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
      sessionStore: const _NoopSessionStore(),
      navigatorKey: navigatorKey,
      onForegroundNotification: (_) => callbacks++,
    );

    WidgetOneSignalService.instance.simulateForegroundNotification(
      <String, dynamic>{'body': 'Once'},
    );
    await tester.pump();
    expect(callbacks, 1);
  });

  testWidgets('foreground notification does not poll an open chat',
      (tester) async {
    var messageGetCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.contains('/messages')) {
        messageGetCount++;
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      final navigatorKey = await mountHost(tester);
      unawaited(WisperBotChat.open(navigatorKey.currentContext!));
      await tester.pumpAndSettle();

      WidgetOneSignalService.instance.simulateForegroundNotification({
        'body': 'Incoming realtime message',
      });
      await tester.pumpAndSettle();

      expect(messageGetCount, 0);
      expect(find.byType(SnackBar), findsNothing);
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
  Future<void> write(
    String namespace,
    WisperBotStoredSession session,
  ) async {}
}
