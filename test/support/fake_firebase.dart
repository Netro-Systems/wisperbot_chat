import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseApp;

import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:firebase_messaging_platform_interface/firebase_messaging_platform_interface.dart';

class FakeFirebase extends FirebasePlatform {
  bool initialized = true;
  final defaultApp = FirebaseAppPlatform(
      '[DEFAULT]',
      const FirebaseOptions(
        apiKey: 'test-key',
        appId: 'test-app',
        messagingSenderId: '123',
        projectId: 'test-project',
      ));
  @override
  List<FirebaseAppPlatform> get apps => initialized ? [defaultApp] : [];
  @override
  FirebaseAppPlatform app([String name = '[DEFAULT]']) => defaultApp;
}

class FakeMessaging extends FirebaseMessagingPlatform {
  String? token = 'test-fcm-token';
  int tokenReads = 0;
  String? apnsToken = 'test-apns-token';
  RemoteMessage? startupMessage;
  int initialReads = 0;
  final registrations = StreamController<String>.broadcast();
  final unregistrations = StreamController<String>.broadcast();
  int registerCalls = 0;
  // These members also let the same fake exercise the real Messaging 17 facade.
  // ignore: annotate_overrides
  Stream<String> get onRegistered => registrations.stream;
  // ignore: annotate_overrides
  Stream<String> get onUnregistered => unregistrations.stream;
  // ignore: annotate_overrides
  Future<void> register(
      {String? vapidKey, String? serviceWorkerScriptPath}) async {
    registerCalls++;
    registrations.add('platform-confirmed-fid');
  }

  final refreshes = StreamController<String>.broadcast();
  @override
  FirebaseMessagingPlatform delegateFor({required FirebaseApp app}) => this;
  @override
  FirebaseMessagingPlatform setInitialValues({bool? isAutoInitEnabled}) => this;
  NotificationSettings Function()? readSettings;
  NotificationSettings Function()? prompt;
  @override
  Future<NotificationSettings> getNotificationSettings() async =>
      readSettings!();
  @override
  Future<NotificationSettings> requestPermission(
          {bool alert = true,
          bool announcement = false,
          bool badge = true,
          bool carPlay = false,
          bool criticalAlert = false,
          bool provisional = false,
          bool sound = true,
          bool providesAppNotificationSettings = false}) async =>
      prompt!();
  @override
  Future<String?> getToken(
      {String? vapidKey, String? serviceWorkerScriptPath}) async {
    tokenReads++;
    return token;
  }

  @override
  Future<String?> getAPNSToken() async => apnsToken;
  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
  @override
  Future<RemoteMessage?> getInitialMessage() async {
    initialReads++;
    final message = startupMessage;
    startupMessage = null;
    return message;
  }
}

final fakeFirebase = FakeFirebase();
final fakeMessaging = FakeMessaging();

void installFakeFirebase() {
  FlutterSecureStorage.setMockInitialValues({});
  fakeFirebase.initialized = true;
  fakeMessaging.token = 'test-fcm-token';
  fakeMessaging.tokenReads = 0;
  fakeMessaging.registerCalls = 0;
  fakeMessaging.apnsToken = 'test-apns-token';
  fakeMessaging.initialReads = 0;
  fakeMessaging.startupMessage = null;
  FirebasePlatform.instance = fakeFirebase;
  FirebaseMessagingPlatform.instance = fakeMessaging;
}

NotificationSettings notificationSettings(AuthorizationStatus status) =>
    NotificationSettings(
      authorizationStatus: status,
      alert: AppleNotificationSetting.enabled,
      announcement: AppleNotificationSetting.disabled,
      badge: AppleNotificationSetting.enabled,
      carPlay: AppleNotificationSetting.disabled,
      lockScreen: AppleNotificationSetting.enabled,
      notificationCenter: AppleNotificationSetting.enabled,
      showPreviews: AppleShowPreviewSetting.always,
      timeSensitive: AppleNotificationSetting.disabled,
      criticalAlert: AppleNotificationSetting.disabled,
      sound: AppleNotificationSetting.enabled,
      providesAppNotificationSettings: AppleNotificationSetting.disabled,
    );
