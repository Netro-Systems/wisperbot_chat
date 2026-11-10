import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/configuration/wisperbot_config.dart';
import 'package:wisperbot_chat/src/application/services/widget_fcm_service.dart';

import '../../support/fixtures/widget_api_fixtures.dart';
import '../../support/fake_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter.baseflow.com/permissions/methods');
  const config = WisperBotConfig(
      widgetKey: 'test',
      registerVisitorOnAppLaunch: false,
      requireNotificationPermission: true);
  final service = WidgetFcmService.instance;
  var granted = false;
  var canRequest = true;
  var acceptsPrompt = false;
  var requests = 0;
  setUp(() {
    installFakeFirebase();
    SharedPreferences.setMockInitialValues({});
    service.resetForTesting();
    granted = false;
    canRequest = true;
    acceptsPrompt = false;
    requests = 0;
    fakeMessaging.readSettings = () => notificationSettings(granted
        ? AuthorizationStatus.authorized
        : canRequest
            ? AuthorizationStatus.notDetermined
            : AuthorizationStatus.denied);
    fakeMessaging.prompt = () {
      requests++;
      granted = acceptsPrompt;
      canRequest = false;
      return fakeMessaging.readSettings!();
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      switch (call.method) {
        case 'checkPermissionStatus':
          return granted ? 1 : (canRequest ? 0 : 4);
        case 'requestPermissions':
          requests++;
          expect(call.arguments, [17]);
          granted = acceptsPrompt;
          canRequest = false;
          return {17: granted ? 1 : 4};
        default:
          return null;
      }
    });
  });
  tearDown(() {
    WisperBotChat.resetForTesting();
    service.resetForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('existing permission does not show a prompt', () async {
    granted = true;
    await service.ensureChatPermission(config);
    expect(requests, 0);
  });
  test('native prompt acceptance allows chat', () async {
    acceptsPrompt = true;
    await service.ensureChatPermission(config);
    expect(requests, 1);
  });
  test('hard denial requires settings; enabling in settings permits retry',
      () async {
    canRequest = false;
    await expectLater(
        service.ensureChatPermission(config),
        throwsA(isA<WisperBotException>().having(
            (error) => error.message,
            'message',
            'Enable notifications from settings to use the support feature.')));
    expect(requests, 0);
    granted = true;
    await service.ensureChatPermission(config);
    expect(requests, 0);
  });
  test('declining the prompt prevents chat', () async {
    await expectLater(
        service.ensureChatPermission(config),
        throwsA(isA<WisperBotException>().having((error) => error.code, 'code',
            WisperBotErrorCode.notificationPermission)));
    expect(requests, 1);
  });
  test('disabled requirement preserves existing behavior', () async {
    await service.ensureChatPermission(const WisperBotConfig(
      widgetKey: 'test',
      requireNotificationPermission: false,
    ));
    expect(requests, 0);
  });

  testWidgets('launch registration defers required permission until chat opens',
      (tester) async {
    final sessionBodies = <Map<String, dynamic>>[];
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/session')) {
        sessionBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });

    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'launch-registration',
        apiBaseUrl: 'https://chat.example.com',
        registerVisitorOnAppLaunch: true,
        requireNotificationPermission: true,
        sessionStore: const _NoopSessionStore(),
      );
      await WisperBotChat.identify(
        const WisperBotUser(name: 'Guest User'),
      );

      expect(requests, 0);
      expect(sessionBodies, hasLength(1));

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => WisperBotChat.open(context),
              child: const Text('Open support'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open support'));
      await tester.pumpAndSettle();

      expect(requests, 1);
      expect(
        find.text(
            'Enable notifications from settings to use the support feature.'),
        findsOneWidget,
      );
      expect(find.byType(WisperBotChatScreen), findsNothing);
      expect(sessionBodies, hasLength(1));
    }, () => client);
  });

  testWidgets('hard denial offers Settings and opens notification settings',
      (tester) async {
    const settingsChannel =
        MethodChannel('com.spencerccf.app_settings/methods');
    final settingsCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(settingsChannel, (call) async {
      settingsCalls.add(call);
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(settingsChannel, null);
    });
    canRequest = false;
    await WisperBotChat.initialize(
      widgetKey: 'test',
      registerVisitorOnAppLaunch: false,
      requireNotificationPermission: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => WisperBotChat.open(context),
            child: const Text('Open support'),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open support'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SnackBarAction, 'Settings'), findsOneWidget);
    expect(find.byType(WisperBotChatScreen), findsNothing);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(settingsCalls, hasLength(1));
    expect(settingsCalls.single.method, 'openSettings');
    expect(settingsCalls.single.arguments, {
      'asAnotherTask': false,
      'type': 'notification',
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  },
      variant: const TargetPlatformVariant(
        <TargetPlatform>{TargetPlatform.android, TargetPlatform.iOS},
      ));

  testWidgets(
      'launcher reports disabled push setup without an unhandled exception',
      (tester) async {
    await WisperBotChat.initialize(
      widgetKey: 'test',
      enablePushNotifications: false,
      registerVisitorOnAppLaunch: false,
      requireNotificationPermission: true,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WisperBotChat.launcher(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Open chat'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Support is unavailable because notification setup is incomplete.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(find.byType(WisperBotChatScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
      'launcher waits for tap and hard denial shows snackbar without starting chat',
      (tester) async {
    canRequest = false;
    final networkRequests = <http.Request>[];
    final client = MockClient((request) async {
      networkRequests.add(request);
      return http.Response('{}', 500);
    });
    await http.runWithClient(() async {
      await WisperBotChat.initialize(
        widgetKey: 'test',
        registerVisitorOnAppLaunch: false,
        requireNotificationPermission: true,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WisperBotChat.launcher()),
      ));
      await tester.pumpAndSettle();
      expect(networkRequests, hasLength(1));
      expect(networkRequests.single.method, 'GET');
      expect(requests, 0);
      await tester.tap(find.byTooltip('Open chat'));
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Enable notifications from settings to use the support feature.'),
          findsOneWidget);
      expect(find.byType(WisperBotChatScreen), findsNothing);
      expect(networkRequests, hasLength(1));
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
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
