import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

import '../../support/fixtures/widget_api_fixtures.dart';

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();
  final testConfig = WisperBotConfig(
    widgetKey: 'notification-test-widget',
    apiBaseUrl: 'https://chat.example.com',
    sessionStore: _NoopSessionStore(),
  );

  setUp(() {
    WisperBotChat.resetForTesting();
    WidgetOneSignalService.instance.resetForTesting();
    WidgetOneSignalService.instance.setPushTokenOverride('test-token');
  });

  tearDown(() {
    WisperBotChat.resetForTesting();
    WidgetOneSignalService.instance.resetForTesting();
  });

  testWidgets('notification click navigates from notification directly to chat message thread',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(sessionResponse()), 200),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      WisperBotChat.initializeNotificationHandlers(
        config: testConfig,
        navigatorKey: navigatorKey,
      );

      expect(find.text('Home Screen'), findsOneWidget);
      expect(find.byType(WisperBotChatScreen), findsNothing);

      // Simulate tapping on a push notification
      WidgetOneSignalService.instance.simulateNotificationClick({
        'conversation_id': 12345,
        'title': 'Support Agent',
        'body': 'Hello! How can I help you today?',
      });

      await tester.pump();
      await tester.pumpAndSettle();

      // Verifies navigation directly opened the chat screen / message thread
      expect(find.byType(WisperBotChatScreen), findsOneWidget);
      expect(find.text('Test support'), findsOneWidget);
    }, () => client);
  });

  testWidgets('cold start notification click is preserved and opens message thread once mounted',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(sessionResponse()), 200),
    );

    await http.runWithClient(() async {
      // Simulate notification click occurring BEFORE handlers are initialized (e.g. app cold start)
      WidgetOneSignalService.instance.simulateNotificationClick({
        'conversation_id': 999,
        'title': 'Agent',
        'body': 'Your order has been updated.',
      });

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      WisperBotChat.initializeNotificationHandlers(
        config: testConfig,
        navigatorKey: navigatorKey,
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byType(WisperBotChatScreen), findsOneWidget);
    }, () => client);
  });

  testWidgets(
      'foreground notification displays an in-app banner with Open action to navigate to thread',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(jsonEncode(sessionResponse()), 200),
    );

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      WisperBotChat.initializeNotificationHandlers(
        config: testConfig,
        navigatorKey: navigatorKey,
      );

      // Simulate notification arriving while in foreground
      WidgetOneSignalService.instance.simulateForegroundNotification({
        'conversation_id': 12345,
        'title': 'Support Agent',
        'body': 'We replied to your message.',
      });

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify in-app SnackBar banner is shown
      expect(find.text('We replied to your message.'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      // Tap "Open" button on the banner
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify it navigates to the chat thread
      expect(find.byType(WisperBotChatScreen), findsOneWidget);
    }, () => client);
  });

  testWidgets('custom onNotificationTapped callback intercepts click event', (tester) async {
    Map<String, dynamic>? interceptedPayload;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Home Screen')),
      ),
    );

    WisperBotChat.initializeNotificationHandlers(
      config: testConfig,
      navigatorKey: navigatorKey,
      onNotificationTapped: (payload) {
        interceptedPayload = payload;
      },
    );

    WidgetOneSignalService.instance.simulateNotificationClick({
      'conversation_id': 555,
      'title': 'Custom Title',
      'body': 'Custom Body',
    });

    await tester.pump();

    expect(interceptedPayload, isNotNull);
    expect(interceptedPayload!['conversation_id'], 555);
    expect(find.byType(WisperBotChatScreen), findsNothing);
  });

  testWidgets('custom onForegroundNotification callback intercepts foreground event',
      (tester) async {
    Map<String, dynamic>? interceptedForegroundPayload;

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        home: const Scaffold(body: Text('Home Screen')),
      ),
    );

    WisperBotChat.initializeNotificationHandlers(
      config: testConfig,
      navigatorKey: navigatorKey,
      onForegroundNotification: (payload) {
        interceptedForegroundPayload = payload;
      },
    );

    WidgetOneSignalService.instance.simulateForegroundNotification({
      'conversation_id': 777,
      'title': 'Agent Message',
      'body': 'Foreground payload test',
    });

    await tester.pump();

    expect(interceptedForegroundPayload, isNotNull);
    expect(interceptedForegroundPayload!['conversation_id'], 777);
    expect(find.text('Foreground payload test'), findsNothing);
  });

  testWidgets('foreground notification refreshes message thread when chat is already open',
      (tester) async {
    var pollCount = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path.contains('/messages')) {
        pollCount++;
        return http.Response(
          jsonEncode(
            pollResponse(
              messages: [
                {
                  'id': 100 + pollCount,
                  'role': 'agent',
                  'type': 'text',
                  'body': 'Incoming message from poll #$pollCount',
                  'sent_by': 'agent',
                  'created_at': '2026-08-03T10:00:00Z',
                }
              ],
            ),
          ),
          200,
        );
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: const Scaffold(body: Text('Home Screen')),
        ),
      );
      await tester.pumpAndSettle();

      WisperBotChat.initializeNotificationHandlers(
        config: testConfig,
        navigatorKey: navigatorKey,
      );

      // Open the chat first
      unawaited(WisperBotChat.open(
        navigatorKey.currentContext!,
        config: testConfig,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(WisperBotChatScreen), findsOneWidget);
      final initialPolls = pollCount;

      // Simulate foreground notification arriving while chat is open
      WidgetOneSignalService.instance.simulateForegroundNotification({
        'conversation_id': 12345,
        'title': 'Support Agent',
        'body': 'Incoming message from poll',
      });

      await tester.pump();
      await tester.pumpAndSettle();

      // Verify chat thread refreshed and no SnackBar is shown
      expect(pollCount, greaterThan(initialPolls));
      expect(find.text('Incoming message from poll #${initialPolls + 1}'), findsOneWidget);
    }, () => client);
  });
}

final class _NoopSessionStore implements WisperBotSessionStore {
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
