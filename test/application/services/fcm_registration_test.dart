import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/widget_fcm_service.dart';

import '../../support/fake_firebase.dart';
import '../../support/fixtures/widget_api_fixtures.dart';

class MemorySessions implements WisperBotSessionStore {
  final sessions = <String, WisperBotStoredSession>{};
  @override
  Future<void> delete(String namespace) async => sessions.remove(namespace);
  @override
  Future<WisperBotStoredSession?> read(String namespace) async =>
      sessions[namespace];
  @override
  Future<void> write(String namespace, WisperBotStoredSession session) async =>
      sessions[namespace] = session;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    installFakeFirebase();
    WidgetFcmService.instance.resetForTesting();
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(WisperBotChat.shutdown);

  Future<void> flush() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  test(
      'registers, refreshes and revokes only the WisperBot association on identity changes',
      () async {
    final registrations = <Map<String, dynamic>>[];
    var sessions = 0;
    final transport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/push')) {
        registrations.add(body);
        expect(request.headers['X-Widget-Token'], isNotEmpty);
        return http.Response('{"ok":true}', 200);
      }
      sessions++;
      expect(body.containsKey('onesignal_id'), isFalse);
      expect(body.containsKey('push'), isFalse);
      return http.Response(
          jsonEncode(sessionResponse(
            visitorId: 'visitor-$sessions',
            token: 'session-$sessions',
            conversationId: sessions,
          )),
          200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
          widgetKey: 'test-widget',
          requireNotificationPermission: false,
          registerVisitorOnAppLaunch: false,
          sessionStore: MemorySessions());
      final controller = WisperBotChat.requireDefaultController();
      await controller.initializeForLaunchRegistration();
      expect(registrations.single['push_token'], 'test-fcm-token');
      fakeMessaging.refreshes.add('refreshed-token');
      await flush();
      expect(registrations.last['push_token'], 'refreshed-token');
      expect(sessions, 1);
      await WisperBotChat.identify(const WisperBotUser(userId: 'account-1'));
      expect(registrations[2]['revoke'], true);
      expect(registrations[2]['push_token'], 'refreshed-token');
      expect(registrations[3]['revoke'], false);
      expect(registrations.map((entry) => entry['installation_id']).toSet(),
          hasLength(1));
      expect(fakeMessaging.token, 'test-fcm-token');
      await WisperBotChat.shutdown();
      final count = registrations.length;
      fakeMessaging.refreshes.add('after-shutdown');
      await flush();
      expect(registrations, hasLength(count));
    }, () => transport);
  });

  test('failed registration retries on resume without recreating the session',
      () async {
    var attempts = 0;
    var sessions = 0;
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/push')) {
        attempts++;
        return http.Response('{}', attempts == 1 ? 503 : 200);
      }
      if (request.url.path.endsWith('/session')) sessions++;
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
          widgetKey: 'test-widget',
          requireNotificationPermission: false,
          registerVisitorOnAppLaunch: false,
          sessionStore: MemorySessions());
      final controller = WisperBotChat.requireDefaultController();
      await controller.initializeForLaunchRegistration();
      expect(attempts, 1);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(attempts, 2);
      expect(sessions, 1);
    }, () => transport);
  });

  test('rejected push registration is diagnosed without preventing chat',
      () async {
    final diagnostics = <WisperBotDiagnosticEvent>[];
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/push')) return http.Response('{}', 403);
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'test-widget',
        requireNotificationPermission: false,
        registerVisitorOnAppLaunch: false,
        sessionStore: MemorySessions(),
        diagnostics: diagnostics.add,
      );
      final controller = WisperBotChat.requireDefaultController();
      await controller.initializeForLaunchRegistration();
      expect(controller.state.phase, WisperBotChatPhase.ready);
      final push = diagnostics
          .where((event) => event.kind == WisperBotDiagnosticKind.push)
          .single;
      expect(push.httpStatus, 403);
      expect(push.errorCode, WisperBotErrorCode.forbidden);
    }, () => transport);
  });

  test(
      'offline revocation survives SDK shutdown and is drained before registration',
      () async {
    var allowRevoke = false;
    final requests = <Map<String, dynamic>>[];
    final sessions = MemorySessions();
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/push')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        return http.Response(
            '{}', body['revoke'] == true && !allowRevoke ? 503 : 200);
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      Future<void> initialize() => WisperBotChat.initialize(
          widgetKey: 'test-widget',
          requireNotificationPermission: false,
          registerVisitorOnAppLaunch: false,
          sessionStore: sessions);
      await initialize();
      await WisperBotChat.requireDefaultController()
          .initializeForLaunchRegistration();
      await WisperBotChat.requireDefaultController().resetSession();
      await WisperBotChat.shutdown();
      requests.clear();
      allowRevoke = true;
      await initialize();
      await WisperBotChat.requireDefaultController()
          .initializeForLaunchRegistration();
      expect(requests.first['revoke'], true);
      expect(requests.last['revoke'], false);
    }, () => transport);
  });

  test('a lost registration acknowledgement is still revoked on reset',
      () async {
    final registrations = <Map<String, dynamic>>[];
    final transport = MockClient((request) async {
      if (request.url.path.endsWith('/push')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        registrations.add(body);
        if (body['revoke'] != true) {
          throw http.ClientException('Lost acknowledgement');
        }
        return http.Response('{}', 200);
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
          widgetKey: 'test-widget',
          requireNotificationPermission: false,
          registerVisitorOnAppLaunch: false,
          sessionStore: MemorySessions());
      final controller = WisperBotChat.requireDefaultController();
      await controller.initializeForLaunchRegistration();
      await controller.resetSession();
      expect(
          registrations.any((body) =>
              body['revoke'] == true && body['push_token'] == 'test-fcm-token'),
          true);
    }, () => transport);
  });

  testWidgets(
      'taps are deduplicated and another visitor cannot trigger the callback',
      (tester) async {
    await tester.pumpWidget(const Directionality(
        textDirection: TextDirection.ltr, child: SizedBox()));
    var taps = 0;
    final transport = MockClient(
        (_) async => http.Response(jsonEncode(sessionResponse()), 200));
    await tester.runAsync(() => http.runWithClient(() async {
          await WisperBotChat.initialize(
              widgetKey: 'test-widget',
              requireNotificationPermission: false,
              registerVisitorOnAppLaunch: false,
              sessionStore: MemorySessions(),
              onNotificationTapped: (_) => taps++);
          await WisperBotChat.requireDefaultController()
              .initializeForLaunchRegistration();
          const message = RemoteMessage(messageId: 'push-1', data: {
            'source': 'wisperbot',
            'type': 'widget_message',
            'widget_key': 'test-widget',
            'visitor_id': 'visitor-1',
          });
          WisperBotChat.handleNotificationTap(message);
          WisperBotChat.handleNotificationTap(message);
          WisperBotChat.handleNotificationTap(
              const RemoteMessage(messageId: 'push-2', data: {
            'source': 'wisperbot',
            'type': 'widget_message',
            'widget_key': 'test-widget',
            'visitor_id': 'other-visitor',
          }));
          await flush();
          expect(taps, 1);
        }, () => transport));
  });

  testWidgets(
      'cold-start tap waits for host identity and navigator before opening chat',
      (tester) async {
    fakeMessaging.startupMessage =
        const RemoteMessage(messageId: 'startup-account', data: {
      'source': 'wisperbot',
      'type': 'widget_message',
      'widget_key': 'test-widget',
      'visitor_id': 'account-visitor',
    });
    final transport = MockClient((request) async {
      final body = request.method == 'POST'
          ? jsonDecode(request.body) as Map<String, dynamic>
          : <String, dynamic>{};
      return http.Response(
          jsonEncode(sessionResponse(
              visitorId: body['user_id'] == 'account-1'
                  ? 'account-visitor'
                  : 'guest-visitor')),
          200);
    });
    await http.runWithClient(() async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.runAsync(() async {
        await WisperBotChat.initialize(
            widgetKey: 'test-widget',
            requireNotificationPermission: false,
            navigatorKey: navigatorKey,
            sessionStore: MemorySessions());
        await WisperBotChat.identify(const WisperBotUser(userId: 'account-1'));
      });
      await tester.pumpWidget(
          MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()));
      await tester.pumpAndSettle();
      expect(find.byType(WisperBotChatScreen), findsOneWidget);
    }, () => transport);
  });

  test('host initialization is required only when push is enabled', () async {
    fakeFirebase.initialized = false;
    await expectLater(
        () => WisperBotChat.initialize(
            widgetKey: 'test', registerVisitorOnAppLaunch: false),
        throwsA(isA<WisperBotException>()));
    await WisperBotChat.shutdown();
    await WisperBotChat.initialize(
        widgetKey: 'test',
        enablePushNotifications: false,
        requireNotificationPermission: false,
        registerVisitorOnAppLaunch: false);
  });

  test(
      'startup message can be shared with host routing and unrelated taps are rejected',
      () async {
    fakeMessaging.startupMessage =
        const RemoteMessage(data: {'source': 'host-app'});
    await WisperBotChat.initialize(
        widgetKey: 'test',
        registerVisitorOnAppLaunch: false,
        requireNotificationPermission: false,
        sessionStore: MemorySessions());
    final initial = await WisperBotChat.getInitialNotification();
    expect(initial!.data['source'], 'host-app');
    expect(fakeMessaging.initialReads, 1);
    expect(WisperBotChat.handleNotificationTap(initial), false);
    expect(
        WisperBotChat.handleNotificationTap(const RemoteMessage(data: {
          'source': 'wisperbot',
          'type': 'widget_message',
          'widget_key': 'another-widget',
        })),
        false);
  });

  test('host-owned startup routing is never consumed when disabled', () async {
    await WisperBotChat.initialize(
        widgetKey: 'test',
        handleInitialNotification: false,
        registerVisitorOnAppLaunch: false,
        requireNotificationPermission: false);
    expect(fakeMessaging.initialReads, 0);
  });
}
