import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

/// Manages OneSignal device registration, identity, and push notification clicks.
final class WidgetOneSignalService {
  WidgetOneSignalService();

  static final WidgetOneSignalService instance = WidgetOneSignalService();

  final StreamController<Map<String, dynamic>> _notificationClicks =
      StreamController<Map<String, dynamic>>.broadcast();

  bool _initialized = false;
  String? _initializedAppId;
  String? _loggedInExternalId;

  /// Stream of data payloads from tapped push notifications.
  Stream<Map<String, dynamic>> get notificationClicks =>
      _notificationClicks.stream;

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

  void _onNotificationClick(OSNotificationClickEvent event) {
    final data = <String, dynamic>{
      ...?event.notification.additionalData,
      if (event.notification.title?.isNotEmpty == true)
        'title': event.notification.title,
      if (event.notification.body?.isNotEmpty == true)
        'body': event.notification.body,
      if (event.notification.launchUrl?.isNotEmpty == true)
        'url': event.notification.launchUrl,
      'notification_id': event.notification.notificationId,
    };
    _notificationClicks.add(data);
  }
}
