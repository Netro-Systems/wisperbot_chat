import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';

/// Uses the host's default Firebase app without changing its messaging settings.
final class WidgetFcmService {
  static final WidgetFcmService instance = WidgetFcmService();

  final _clicks = StreamController<Map<String, dynamic>>.broadcast();
  final _foreground = StreamController<Map<String, dynamic>>.broadcast();
  final _tokens = StreamController<String>.broadcast();
  Stream<Map<String, dynamic>> get notificationClicks => _clicks.stream;
  Stream<Map<String, dynamic>> get foregroundNotifications =>
      _foreground.stream;
  Stream<String> get tokenChanges => _tokens.stream;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<RemoteMessage?>? _initialMessage;
  Map<String, dynamic>? _pendingClick;
  String? _tokenOverride;
  int _owners = 0;

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void validateHost() {
    if (!isSupported) return;
    if (Firebase.apps.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'Initialize Firebase before enabling WisperBot push notifications.',
        retryable: false,
      );
    }
    Firebase.app();
  }

  void retain() {
    validateHost();
    if (!isSupported || _owners++ > 0) return;
    _subscriptions.addAll([
      FirebaseMessaging.onMessage.listen((message) {
        _foreground.add(payload(message));
      }),
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        forwardTap(payload(message));
      }),
      FirebaseMessaging.instance.onTokenRefresh
          .listen(_tokens.add, onError: (Object _) {}),
    ]);
  }

  Future<void> release() async {
    if (_owners == 0 || --_owners > 0) return;
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
  }

  /// Shares the single-consumption startup message with cooperating host code.
  Future<RemoteMessage?> initialMessage() =>
      _initialMessage ??= FirebaseMessaging.instance.getInitialMessage();

  void forwardTap(Map<String, dynamic> data) {
    if (_clicks.hasListener) {
      _clicks.add(data);
    } else {
      _pendingClick = data;
    }
  }

  void flushPendingTap() {
    final pending = _pendingClick;
    _pendingClick = null;
    if (pending != null) _clicks.add(pending);
  }

  Map<String, dynamic> payload(RemoteMessage message) => {
        ...message.data,
        if (message.messageId != null) 'notification_id': message.messageId,
        if (message.notification?.title != null)
          'title': message.notification!.title,
        if (message.notification?.body != null)
          'body': message.notification!.body,
      };

  Future<void> ensureChatPermission(WisperBotConfig config) async {
    if (!config.requireNotificationPermission) return;
    if (!config.enablePushNotifications) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'Support is unavailable because notification setup is incomplete.',
        retryable: false,
      );
    }
    if (!isSupported) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unsupported,
        message: 'Notification permission gating supports Android and iOS.',
        retryable: false,
      );
    }
    validateHost();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      var authorization =
          (await FirebaseMessaging.instance.getNotificationSettings())
              .authorizationStatus;
      if (authorization == AuthorizationStatus.notDetermined) {
        authorization = (await FirebaseMessaging.instance.requestPermission())
            .authorizationStatus;
      }
      if (authorization == AuthorizationStatus.authorized ||
          authorization == AuthorizationStatus.provisional) {
        return;
      }
      throw const WisperBotException(
        code: WisperBotErrorCode.notificationPermission,
        message:
            'Enable notifications from settings to use the support feature.',
        retryable: true,
      );
    }
    var status = await Permission.notification.status;
    if (status.isGranted || status.isProvisional) return;
    if (!status.isPermanentlyDenied && !status.isRestricted) {
      status = await Permission.notification.request();
      if (status.isGranted || status.isProvisional) return;
    }
    throw WisperBotException(
      code: WisperBotErrorCode.notificationPermission,
      message: status.isPermanentlyDenied || status.isRestricted
          ? 'Enable notifications from settings to use the support feature.'
          : 'Notification permission is required to use support.',
      retryable: true,
    );
  }

  /// Reads an existing registration without requesting notification permission.
  Future<String?> currentPushToken() async {
    if (_tokenOverride != null) return _tokenOverride;
    if (!isSupported) return null;
    validateHost();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        return null;
      }
      return await FirebaseMessaging.instance.getToken();
    } on Object {
      // APNs/FCM can be temporarily unavailable. Registration retries separately.
      return null;
    }
  }

  @visibleForTesting
  void setPushTokenOverride(String? token) => _tokenOverride = token;
  @visibleForTesting
  void simulateNotificationClick(Map<String, dynamic> data) => forwardTap(data);
  @visibleForTesting
  void simulateForegroundNotification(Map<String, dynamic> data) =>
      _foreground.add(data);
  @visibleForTesting
  void simulateTokenRefresh(String token) => _tokens.add(token);
  @visibleForTesting
  void resetForTesting() {
    _tokenOverride = null;
    _pendingClick = null;
    _initialMessage = null;
  }
}
