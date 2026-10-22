import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/widget_fcm_service.dart';
import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../domain/entities/wisperbot_user.dart';
import '../facade/wisperbot_chat.dart';

/// Builds the host application with the SDK-owned navigator and runtime.
typedef WisperBotChatHostBuilder = Widget Function(
  BuildContext context,
  GlobalKey<NavigatorState> navigatorKey,
  WisperBotChatController controller,
);

/// Owns WisperBot initialization, navigation, and runtime resources.
class WisperBotChatHost extends StatefulWidget {
  /// Creates the root WisperBot integration.
  const WisperBotChatHost({
    super.key,
    required this.config,
    required this.builder,
    this.initialUser,
    this.handleInitialNotification = true,
    this.onNotificationTapped,
    this.onForegroundNotification,
  });

  /// Static SDK and presentation configuration.
  final WisperBotConfig config;

  /// Whether the SDK reads the startup notification. Disable for host-owned routing.
  final bool handleInitialNotification;

  /// Optional visitor identity available when the application starts.
  final WisperBotUser? initialUser;

  /// Builds the host app with the SDK-owned navigator and controller.
  final WisperBotChatHostBuilder builder;

  /// Overrides automatic chat opening for tapped notifications.
  final void Function(Map<String, dynamic> payload)? onNotificationTapped;

  /// Receives notifications delivered while the app is in the foreground.
  final void Function(Map<String, dynamic> payload)? onForegroundNotification;

  @override
  State<WisperBotChatHost> createState() => _WisperBotChatHostState();
}

class _WisperBotChatHostState extends State<WisperBotChatHost> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final WisperBotClient _client;
  late final WisperBotChatController _controller;
  StreamSubscription<Map<String, dynamic>>? _notificationClickSubscription;
  StreamSubscription<Map<String, dynamic>>? _foregroundSubscription;
  Map<String, dynamic>? _pendingNotificationPayload;

  @override
  void initState() {
    super.initState();
    _client = WisperBotClient.fromConfig(
      config: widget.config,
      user: widget.initialUser,
    );
    _controller = WisperBotChatController(client: _client);
    _initializeNotifications();
    if (widget.config.registerVisitorOnAppLaunch) {
      unawaited(
        _controller.initializeForLaunchRegistration().catchError((_) {}),
      );
    }
  }

  bool _ownsPushService = false;
  final Set<String> _handledPushIds = {};

  void _initializeNotifications() {
    final config = widget.config;
    if (config.enablePushNotifications &&
        WidgetFcmService.instance.isSupported) {
      WidgetFcmService.instance.retain();
      _ownsPushService = true;
    }
    _notificationClickSubscription = WidgetFcmService
        .instance.notificationClicks
        .listen(_handleNotificationClick);
    _foregroundSubscription =
        WidgetFcmService.instance.foregroundNotifications.listen((payload) {
      if (_controller.acceptsPushPayload(payload)) {
        widget.onForegroundNotification?.call(payload);
      }
    });
    WidgetFcmService.instance.flushPendingTap();
    if (_ownsPushService && widget.handleInitialNotification) {
      unawaited(WidgetFcmService.instance.initialMessage().then((message) {
        if (mounted && message != null) {
          _handleNotificationClick(WidgetFcmService.instance.payload(message));
        }
      }).catchError((_) {}));
    }
  }

  void _handleNotificationClick(Map<String, dynamic> payload) {
    unawaited(_routeNotification(payload).catchError((_) {}));
  }

  Future<void> _routeNotification(Map<String, dynamic> payload) async {
    if (payload['widget_key'] != widget.config.widgetKey ||
        payload['source'] != 'wisperbot') {
      return;
    }
    await _controller.initializeForLaunchRegistration();
    if (!mounted || !_controller.acceptsPushPayload(payload)) return;
    final id = payload['notification_id']?.toString();
    if (id != null && !_handledPushIds.add(id)) return;
    if (_handledPushIds.length > 100) {
      _handledPushIds.remove(_handledPushIds.first);
    }
    final callback = widget.onNotificationTapped;
    if (callback != null) {
      callback(payload);
      return;
    }
    final context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _pendingNotificationPayload = payload;
      _schedulePendingNotificationOpen();
      return;
    }
    _openNotification(context, payload);
  }

  void _schedulePendingNotificationOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final payload = _pendingNotificationPayload;
      final context = _navigatorKey.currentContext;
      if (payload == null ||
          context == null ||
          !_controller.acceptsPushPayload(payload)) {
        return;
      }
      _pendingNotificationPayload = null;
      _openNotification(context, payload);
    });
  }

  void _openNotification(
    BuildContext context,
    Map<String, dynamic> payload,
  ) {
    unawaited(
      WisperBotChat.openChatboxFromNotification(
        context: context,
        controller: _controller,
        payload: payload,
      ).catchError((_) => null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pendingNotificationPayload != null) {
      _schedulePendingNotificationOpen();
    }
    return widget.builder(context, _navigatorKey, _controller);
  }

  @override
  void dispose() {
    unawaited(_notificationClickSubscription?.cancel());
    unawaited(_foregroundSubscription?.cancel());
    if (_ownsPushService) unawaited(WidgetFcmService.instance.release());
    unawaited(_controller.dispose().whenComplete(_client.close));
    super.dispose();
  }
}
