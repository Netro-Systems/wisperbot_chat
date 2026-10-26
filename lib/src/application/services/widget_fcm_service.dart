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
  final _installationIds = StreamController<String?>.broadcast();
  StreamSubscription<String>? _registeredSubscription;
  StreamSubscription<String>? _unregisteredSubscription;
  String? _installationId;
  bool _explicitlyUnregistered = false;
  Future<String?>? _registration;
  Object? _messagingOverride;

  // Dynamic access keeps the default token path compatible with Messaging 15/16.
  dynamic get _installationMessaging =>
      _messagingOverride ?? FirebaseMessaging.instance;

  Stream<String?> registrationChanges(
          {bool useFirebaseInstallationId = false}) =>
      useFirebaseInstallationId ? _installationIds.stream : tokenChanges;
  Stream<Map<String, dynamic>> get notificationClicks => _clicks.stream;
  Stream<Map<String, dynamic>> get foregroundNotifications =>
      _foreground.stream;
  Stream<String> get tokenChanges => _tokens.stream;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<RemoteMessage?>? _initialMessage;
  Map<String, dynamic>? _pendingClick;
  String? _tokenOverride;
  int _owners = 0;

  void _log(String stage) {
    if (kDebugMode) debugPrint('WisperBot push: $stage');
  }

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
    _log('FCM listeners attached');
    _subscriptions.addAll([
      FirebaseMessaging.onMessage.listen((message) {
        _log('foreground notification received '
            '(wisperbot=${message.data['source'] == 'wisperbot'})');
        _foreground.add(payload(message));
      }),
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _log('background notification opened');
        forwardTap(payload(message));
      }),
      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _log('FCM token refreshed');
        _tokens.add(token);
      }, onError: (Object _) {
        _log('FCM token refresh failed');
      }),
    ]);
  }

  Future<void> release() async {
    if (_owners == 0 || --_owners > 0) return;
    final subscriptions = List.of(_subscriptions);
    _subscriptions.clear();
    await _registeredSubscription?.cancel();
    await _unregisteredSubscription?.cancel();
    _registeredSubscription = null;
    _unregisteredSubscription = null;
    _installationId = null;
    _explicitlyUnregistered = false;
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
  Future<String?> currentPushToken(
      {bool useFirebaseInstallationId = false}) async {
    if (_tokenOverride != null) return _tokenOverride;
    if (!isSupported) return null;
    validateHost();
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await FirebaseMessaging.instance.getAPNSToken() == null) {
        _log('token unavailable: waiting for APNs');
        return null;
      }
      if (useFirebaseInstallationId) return await _currentInstallationId();
      final token = await FirebaseMessaging.instance.getToken();
      _log(token == null || token.isEmpty
          ? 'FCM token unavailable'
          : 'FCM token available');
      return token;
    } on Object {
      _log('FCM token lookup failed; registration will retry');
      // APNs/FCM can be temporarily unavailable. Registration retries separately.
      return null;
    }
  }

  Future<String?> _currentInstallationId() {
    if (_explicitlyUnregistered) return Future<String?>.value();
    final existing = _installationId;
    if (existing != null) return Future<String?>.value(existing);
    return _registration ??= _registerInstallation().whenComplete(() {
      _registration = null;
    });
  }

  Future<String?> _registerInstallation() async {
    final dynamic messaging = _installationMessaging;
    try {
      if (_registeredSubscription == null) {
        final registered = messaging.onRegistered as Stream<String>;
        final unregistered = messaging.onUnregistered as Stream<String>;
        _registeredSubscription = registered.listen((fid) {
          if (fid.isEmpty) return;
          _installationId = fid;
          _explicitlyUnregistered = false;
          _log('FCM installation registered');
          _installationIds.add(fid);
        }, onError: (Object _) {
          _log('FCM installation registration stream failed');
        });
        _unregisteredSubscription = unregistered.listen((fid) {
          if (_installationId != null && _installationId != fid) return;
          _installationId = null;
          _explicitlyUnregistered = true;
          _log('FCM installation unregistered');
          _installationIds.add(null);
        }, onError: (Object _) {
          _log('FCM installation unregistration stream failed');
        });
      }
    } on NoSuchMethodError {
      _log('FID messaging requires firebase_messaging 17 or newer');
      return null;
    }
    final result = Completer<String?>();
    final subscription = _installationIds.stream.listen((fid) {
      if (!result.isCompleted) result.complete(fid);
    });
    try {
      // Subscribe first: register() delivers its ID through onRegistered.
      await (messaging.register() as Future<void>)
          .timeout(const Duration(seconds: 10));
      return await result.future
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
    } finally {
      await subscription.cancel();
    }
  }

  @visibleForTesting
  void setMessagingOverride(Object? messaging) =>
      _messagingOverride = messaging;

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
    _messagingOverride = null;
    _installationId = null;
    _explicitlyUnregistered = false;
    _registration = null;
    _pendingClick = null;
    _initialMessage = null;
  }
}
