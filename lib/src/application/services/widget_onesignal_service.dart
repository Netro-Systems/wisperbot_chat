import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Manages OneSignal device registration, identity, and push notification clicks.
final class WidgetOneSignalService {
  WidgetOneSignalService();

  static final WidgetOneSignalService instance = WidgetOneSignalService();

  late final StreamController<Map<String, dynamic>> _notificationClicks =
      StreamController<Map<String, dynamic>>.broadcast(
    onListen: () {
      if (_pendingNotificationClick != null) {
        Future.microtask(() {
          if (_pendingNotificationClick != null) {
            _notificationClicks.add(_pendingNotificationClick!);
            _pendingNotificationClick = null;
          }
        });
      }
    },
  );

  final StreamController<Map<String, dynamic>> _foregroundNotifications =
      StreamController<Map<String, dynamic>>.broadcast();

  Map<String, dynamic>? _pendingNotificationClick;
  bool _initialized = false;
  String? _initializedAppId;
  String? _loggedInExternalId;

  /// Stream of data payloads from tapped push notifications.
  Stream<Map<String, dynamic>> get notificationClicks => _notificationClicks.stream;

  /// Stream of data payloads from notifications arriving while the app is in the foreground.
  Stream<Map<String, dynamic>> get foregroundNotifications => _foregroundNotifications.stream;

  /// Whether OneSignal has been successfully initialized.
  bool get isInitialized => _initialized;

  /// Initializes OneSignal with [appId] and attaches notification click listeners.
  Future<void> initialize({required String appId}) async {
    if (appId.trim().isEmpty) return;
    if (_initialized && _initializedAppId == appId) return;

    _initialized = true;
    _initializedAppId = appId;

    try {
      if (kDebugMode) {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
      }
      OneSignal.initialize(appId);
      OneSignal.Notifications.addClickListener(_onNotificationClick);
      OneSignal.Notifications.addForegroundWillDisplayListener(
        _onForegroundWillDisplay,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[WisperBot] OneSignal initialization failed: $e');
      }
      _initialized = false;
      _initializedAppId = null;
    }
  }

  /// Requests push notification permission and opts in to push subscription.
  Future<void> requestPermission() async {
    if (!_initialized) return;
    try {
      await OneSignal.User.pushSubscription.optIn();
      await OneSignal.Notifications.requestPermission(false);
    } catch (_) {}
  }

  /// Links a verified user external ID to OneSignal.
  Future<void> login(String externalId) async {
    if (!_initialized || externalId.trim().isEmpty) return;
    if (_loggedInExternalId == externalId) return;
    try {
      await OneSignal.login(externalId.trim());
      _loggedInExternalId = externalId.trim();
    } catch (_) {}
  }

  /// Logs out the user from OneSignal and opts out of pushes on reset.
  Future<void> logout() async {
    if (!_initialized) return;
    try {
      await OneSignal.User.pushSubscription.optOut();
      await OneSignal.logout();
      _loggedInExternalId = null;
    } catch (_) {}
  }

  /// Resolves the current OneSignal Push Subscription ID with retries.
  Future<String?> currentPushToken({bool ensureReady = true}) async {
    if (_pushTokenOverride != null) return _pushTokenOverride;
    if (!_initialized) return null;

    if (ensureReady) {
      await requestPermission();
    }

    try {
      for (var attempt = 1; attempt <= 8; attempt++) {
        final subscriptionId = OneSignal.User.pushSubscription.id;
        if (subscriptionId != null && subscriptionId.isNotEmpty) {
          if (kDebugMode) {
            debugPrint(
              '[WisperBot] Resolved OneSignal subscription ID: $subscriptionId (attempt $attempt)',
            );
          }
          return subscriptionId;
        }
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String? _pushTokenOverride;

  @visibleForTesting
  void setPushTokenOverride(String? token) {
    _pushTokenOverride = token;
  }

  void _onNotificationClick(OSNotificationClickEvent event) {
    event.preventDefault();
    final data = _extractPayload(event.notification);
    if (_notificationClicks.hasListener) {
      _notificationClicks.add(data);
    } else {
      _pendingNotificationClick = data;
    }
  }

  void _onForegroundWillDisplay(OSNotificationWillDisplayEvent event) {
    final data = _extractPayload(event.notification);
    _foregroundNotifications.add(data);
  }

  Map<String, dynamic> _extractPayload(OSNotification notification) {
    return <String, dynamic>{
      ...?notification.additionalData,
      if (notification.title?.isNotEmpty == true) 'title': notification.title,
      if (notification.body?.isNotEmpty == true) 'body': notification.body,
      if (notification.launchUrl?.isNotEmpty == true) 'url': notification.launchUrl,
      'notification_id': notification.notificationId,
    };
  }

  @visibleForTesting
  void simulateNotificationClick(Map<String, dynamic> payload) {
    if (_notificationClicks.hasListener) {
      _notificationClicks.add(payload);
    } else {
      _pendingNotificationClick = payload;
    }
  }

  @visibleForTesting
  void simulateForegroundNotification(Map<String, dynamic> payload) {
    _foregroundNotifications.add(payload);
  }

  @visibleForTesting
  void resetForTesting() {
    _pushTokenOverride = null;
    _pendingNotificationClick = null;
    _initialized = false;
    _initializedAppId = null;
    _loggedInExternalId = null;
  }
}
