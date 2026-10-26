import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/widget_fcm_service.dart';

import '../../support/fake_firebase.dart';
import '../../support/fixtures/widget_api_fixtures.dart';
import 'fcm_registration_test.dart' show MemorySessions;

class InstallationMessaging {
  final registered = StreamController<String>.broadcast();
  final unregistered = StreamController<String>.broadcast();
  Stream<String> get onRegistered => registered.stream;
  Stream<String> get onUnregistered => unregistered.stream;
  String fid = 'test-installation-fid';
  int registrations = 0;
  bool fail = false;

  Future<void> register() async {
    registrations++;
    if (fail) {
      throw FirebaseException(
          plugin: 'firebase_messaging', code: 'unavailable');
    }
    registered.add(fid);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = WidgetFcmService.instance;
  late InstallationMessaging messaging;
  late List<Map<String, dynamic>> requests;
  late MockClient transport;

  setUp(() {
    installFakeFirebase();
    service.resetForTesting();
    messaging = InstallationMessaging();
    service.setMessagingOverride(messaging);
    SharedPreferences.setMockInitialValues({});
    requests = [];
    transport = MockClient((request) async {
      if (request.url.path.endsWith('/push')) {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        expect(request.headers['X-Widget-Token'], isNotEmpty);
        return http.Response('{"ok":true}', 200);
      }
      return http.Response(jsonEncode(sessionResponse()), 200);
    });
  });
  tearDown(() async {
    await WisperBotChat.shutdown();
    service.resetForTesting();
    await messaging.registered.close();
    await messaging.unregistered.close();
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> flush() async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  Future<WisperBotChatController> initialize({bool fid = true}) async {
    await WisperBotChat.initialize(
      widgetKey: 'test-widget',
      useFirebaseInstallationId: fid,
      requireNotificationPermission: false,
      registerVisitorOnAppLaunch: false,
      sessionStore: MemorySessions(),
    );
    final controller = WisperBotChat.requireDefaultController();
    await controller.initializeForLaunchRegistration();
    return controller;
  }

  test('FID opt-in registers before reading the ID and never calls getToken',
      () async {
    await http.runWithClient(() async {
      await initialize();
      expect(messaging.registrations, 1);
      expect(fakeMessaging.tokenReads, 0);
      expect(requests.single['push_token'], messaging.fid);
      expect(requests.single['provider'], 'fcm');
      expect(requests.single['revoke'], false);
    }, () => transport);
  });

  test(
      'guest login logout and guest restoration retain one installation and revoke old sessions',
      () async {
    var sessions = 0;
    final sessionRequests = <Map<String, dynamic>>[];
    final guestTransport = MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/push')) {
        requests.add({...body, 'session': request.headers['X-Widget-Token']});
        return http.Response('{"ok":true}', 200);
      }
      if (!request.url.path.endsWith('/session')) {
        return http.Response('{"ok":true}', 200);
      }
      sessionRequests.add(body);
      sessions++;
      return http.Response(
          jsonEncode(sessionResponse(
            visitorId: 'visitor-$sessions',
            token: 'session-$sessions',
            conversationId: sessions,
          )),
          200);
    });
    await http.runWithClient(() async {
      final controller = await initialize();
      expect(controller.user?.userId, isNull);
      expect(sessionRequests.single['user_id'], isNull);
      expect(requests.single['session'], 'session-1');
      await WisperBotChat.identify(const WisperBotUser(userId: 'signed-in'));
      expect(controller.user?.userId, 'signed-in');
      await WisperBotChat.identify(const WisperBotUser(name: 'Guest'));
      expect(controller.user?.userId, isNull);
      expect(controller.state.phase, WisperBotChatPhase.ready);
      final revocations = requests.where((r) => r['revoke'] == true).toList();
      expect(revocations.map((r) => r['session']), ['session-1', 'session-2']);
      expect(requests.last['revoke'], false);
      expect(requests.last['session'], 'session-3');
      expect(requests.last['push_token'], messaging.fid);
      expect(requests.map((r) => r['installation_id']).toSet(), hasLength(1));
      expect(messaging.registrations, 1);
      expect(fakeMessaging.tokenReads, 0);
    }, () => guestTransport);
  });

  test(
      'Messaging 17 facade bridges confirmed registrations without calling token APIs',
      () async {
    final dynamic firebase = FirebaseMessaging.instance;
    try {
      firebase.onRegistered;
    } on NoSuchMethodError {
      markTestSkipped(
          'Requires Firebase Messaging 17; also run through the host package.');
      return;
    }
    service.setMessagingOverride(null);
    await http.runWithClient(() async {
      await initialize();
      expect(requests.single['push_token'], 'platform-confirmed-fid');
      expect(fakeMessaging.registerCalls, 1);
      expect(fakeMessaging.tokenReads, 0);
    }, () => transport);
  });

  test('default remains legacy tokens with no FID API calls', () async {
    await http.runWithClient(() async {
      await initialize(fid: false);
      expect(requests.single['push_token'], 'test-fcm-token');
      expect(fakeMessaging.tokenReads, 1);
      expect(messaging.registrations, 0);
    }, () => transport);
  });

  test(
      'FID changes update registration and identity changes revoke only the SDK association',
      () async {
    await http.runWithClient(() async {
      await initialize();
      messaging.registered.add('rotated-fid');
      await flush();
      expect(requests.last['push_token'], 'rotated-fid');
      fakeMessaging.refreshes.add('unrelated-legacy-token');
      await flush();
      expect(requests.last['push_token'], 'rotated-fid');
      await WisperBotChat.identify(const WisperBotUser(userId: 'other-user'));
      expect(requests.where((r) => r['revoke'] == true).single['push_token'],
          'rotated-fid');
      expect(requests.last['revoke'], false);
      expect(requests.last['push_token'], 'rotated-fid');
      expect(messaging.registrations, 1);
      expect(fakeMessaging.tokenReads, 0);
    }, () => transport);
  });

  test(
      'host unregister revokes the SDK association without re-registering the host',
      () async {
    await http.runWithClient(() async {
      final controller = await initialize();
      messaging.unregistered.add(messaging.fid);
      await flush();
      expect(requests.last['revoke'], true);
      final count = requests.length;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(requests.length, count);
      expect(messaging.registrations, 1);
      messaging.registered.add('host-registered-again');
      await flush();
      expect(requests.last['push_token'], 'host-registered-again');
      expect(requests.last['revoke'], false);
      expect(messaging.registrations, 1);
    }, () => transport);
  });

  test(
      'rapid host unregister and register are serialized without revoking the new registration',
      () async {
    await http.runWithClient(() async {
      await initialize();
      messaging.unregistered.add(messaging.fid);
      messaging.registered.add('new-host-fid');
      await flush();
      expect(requests.last['push_token'], 'new-host-fid');
      expect(requests.last['revoke'], false);
      expect(requests.where((r) => r['revoke'] == true), hasLength(1));
      expect(messaging.registrations, 1);
    }, () => transport);
  });

  test('stale unregistration cannot revoke the replacement FID', () async {
    await http.runWithClient(() async {
      await initialize();
      messaging.registered.add('replacement-fid');
      await flush();
      final count = requests.length;
      messaging.unregistered.add(messaging.fid);
      await flush();
      expect(requests.length, count);
      expect(requests.last['push_token'], 'replacement-fid');
    }, () => transport);
  });

  test('registration errors leave chat usable and retry on resume', () async {
    messaging.fail = true;
    await http.runWithClient(() async {
      final controller = await initialize();
      expect(controller.state.phase, WisperBotChatPhase.ready);
      expect(requests, isEmpty);
      messaging.fail = false;
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(requests.single['push_token'], messaging.fid);
      expect(messaging.registrations, 2);
    }, () => transport);
  });

  test('older Messaging versions fail FID opt-in safely without breaking chat',
      () async {
    service.setMessagingOverride(Object());
    await http.runWithClient(() async {
      final controller = await initialize();
      expect(controller.state.phase, WisperBotChatPhase.ready);
      expect(requests, isEmpty);
      expect(fakeMessaging.tokenReads, 0);
    }, () => transport);
  });

  test('iOS waits for APNs without registering or prompting', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    fakeMessaging.apnsToken = null;
    await http.runWithClient(() async {
      await initialize();
      expect(messaging.registrations, 0);
      expect(requests, isEmpty);
      expect(fakeMessaging.tokenReads, 0);
    }, () => transport);
  });

  test('shutdown releases FID listeners and subsequent events cannot register',
      () async {
    await http.runWithClient(() async {
      await initialize();
      await WisperBotChat.shutdown();
      expect(messaging.registered.hasListener, false);
      expect(messaging.unregistered.hasListener, false);
      final count = requests.length;
      messaging.registered.add('after-shutdown');
      await flush();
      expect(requests.length, count);
    }, () => transport);
  });
}
