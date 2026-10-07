import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/widget_onesignal_service.dart';

import '../../support/builders/message_builder.dart';
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

  testWidgets('shared unread count supports a host-owned launcher button',
      (tester) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode(
          sessionResponse(
            messages: <Map<String, Object?>>[
              message(id: 1, role: 'agent', body: 'Unread reply'),
            ],
          ),
        ),
        200,
      ),
    );

    await http.runWithClient(() async {
      await mountHost(tester);
      await WisperBotChat.requireDefaultController().initialize();
      await tester.pump();

      expect(WisperBotChat.unreadCount.value, 1);

      await WisperBotChat.requireDefaultController().markRead();
      await tester.pump();

      expect(WisperBotChat.unreadCount.value, 0);
    }, () => client);
  });

  testWidgets('badge wraps any widget, honors dot offset, and clears on open',
      (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        return http.Response(
          jsonEncode(
            sessionResponse(
              messages: <Map<String, Object?>>[
                message(id: 1, role: 'agent', body: 'Unread reply'),
              ],
            ),
          ),
          200,
        );
      }
      if (request.url.path.endsWith('/read')) {
        return http.Response('{"ok":true}', 200);
      }
      throw StateError('Unexpected request: ${request.url}');
    });

    await http.runWithClient(() async {
      final navigatorKey = await mountHost(tester);
      await WisperBotChat.requireDefaultController().initialize();
      await tester.pump();

      await tester.pumpWidget(MaterialApp(
        navigatorKey: navigatorKey,
        home: Scaffold(
          body: Center(
            child: Container(
              key: const ValueKey<String>('badge-parent'),
              width: 66,
              height: 66,
              color: Colors.yellow,
              child: WisperBotChat.badge(
                backgroundColor: Colors.green,
                smallSize: 10,
                offset: const Offset(-3, 4),
                child: GestureDetector(
                  key: const ValueKey<String>('custom-chat-widget'),
                  onTap: () => WisperBotChat.open(
                    navigatorKey.currentContext!,
                  ),
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(WisperBotChat.unreadCount.value, 1);
      final childRect = tester.getRect(
        find.byKey(const ValueKey<String>('custom-chat-widget')),
      );
      final indicator = find.byKey(
        const ValueKey<String>('wisperbot-unread-badge-indicator'),
      );
      final indicatorRect = tester.getRect(indicator);
      expect(childRect.size, const Size(56, 56));
      expect(indicatorRect.size, const Size(10, 10));
      expect(indicatorRect.right, childRect.right - 3);
      expect(indicatorRect.top, childRect.top + 4);
      final indicatorContainer = tester.widget<Container>(indicator);
      expect(
        (indicatorContainer.decoration! as ShapeDecoration).color,
        Colors.green,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('custom-chat-widget')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WisperBotChatScreen), findsOneWidget);
      expect(WisperBotChat.unreadCount.value, 0);
    }, () => client);
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
