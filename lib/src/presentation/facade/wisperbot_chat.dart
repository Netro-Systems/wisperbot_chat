import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/widget_onesignal_service.dart';
import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/events/chat_event.dart';
import '../screen/chat_screen.dart';
import '../view/chat_view.dart';

/// Static helpers for modal chat presentation, push notifications, and reset.
abstract final class WisperBotChat {
  static final Map<String, Future<WisperBotChatResult?>> _activePresentations =
      <String, Future<WisperBotChatResult?>>{};
  static final Map<String, WisperBotChatController> _ownedControllers =
      <String, WisperBotChatController>{};
  static StreamSubscription<Map<String, dynamic>>?
      _notificationClickSubscription;
  static void Function(Map<String, dynamic> payload)? _onNotificationTapped;
  static WisperBotConfig? _lastConfig;
  static GlobalKey<NavigatorState>? _navigatorKey;

  /// Initializes OneSignal push notification handlers for visitor chat.
  ///
  /// Call this in your host app's `main()` or splash screen:
  /// ```dart
  /// WisperBotChat.initializeNotificationHandlers(
  ///   config: config,
  ///   navigatorKey: navigatorKey,
  /// );
  /// ```
  static void initializeNotificationHandlers({
    WisperBotConfig? config,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(Map<String, dynamic> payload)? onNotificationTapped,
  }) {
    if (config != null) _lastConfig = config;
    if (navigatorKey != null) _navigatorKey = navigatorKey;
    if (onNotificationTapped != null) {
      _onNotificationTapped = onNotificationTapped;
    }

    final appId =
        config?.oneSignalAppId ?? WisperBotConfig.defaultOneSignalAppId;
    WidgetOneSignalService.instance.initialize(appId: appId);

    _notificationClickSubscription?.cancel();
    _notificationClickSubscription = WidgetOneSignalService
        .instance.notificationClicks
        .listen(_handleNotificationClick);
  }

  /// Sets or updates the custom notification tapped callback.
  static void setOnNotificationTappedCallback(
    void Function(Map<String, dynamic> payload) callback,
  ) {
    _onNotificationTapped = callback;
  }

  /// Opens the chatbox from a notification click.
  static Future<WisperBotChatResult?> openChatboxFromNotification({
    BuildContext? context,
    WisperBotConfig? config,
    Map<String, dynamic>? payload,
  }) {
    final effectiveConfig = config ?? _lastConfig;
    if (effectiveConfig == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'No WisperBotConfig provided for notification opening.',
        retryable: false,
      );
    }
    final effectiveContext = context ?? _navigatorKey?.currentContext;
    if (effectiveContext == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'No BuildContext or navigatorKey available to open chat.',
        retryable: false,
      );
    }

    return open(effectiveContext, config: effectiveConfig);
  }

  static void _handleNotificationClick(Map<String, dynamic> payload) {
    if (_onNotificationTapped != null) {
      _onNotificationTapped!(payload);
      return;
    }

    if (_navigatorKey?.currentContext != null && _lastConfig != null) {
      openChatboxFromNotification(
        context: _navigatorKey!.currentContext,
        config: _lastConfig,
        payload: payload,
      );
    }
  }

  /// Opens at most one chat presentation for the configuration scope.
  ///
  /// Uses [config.presentation] unless [presentation] overrides it. A supplied
  /// [controller] remains owned by the caller. Throws [WisperBotException]
  /// when configuration is invalid or the controller belongs to another
  /// identity/widget scope.
  static Future<WisperBotChatResult?> open(
    BuildContext context, {
    required WisperBotConfig config,
    WisperBotChatController? controller,
    WisperBotPresentation? presentation,
  }) {
    validateWisperBotRuntimeConfig(config);
    final scope = wisperBotPresentationScope(config);
    final active = _activePresentations[scope];
    if (active != null) return active;

    if (controller != null &&
        wisperBotPresentationScope(controller.config) != scope) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'The supplied controller does not match the chat configuration.',
        retryable: false,
      );
    }

    final completer = Completer<WisperBotChatResult?>();
    _activePresentations[scope] = completer.future;
    unawaited(
      _openPresentation(
        context,
        scope: scope,
        config: config,
        suppliedController: controller,
        presentation: presentation ?? config.presentation,
      ).then(completer.complete, onError: completer.completeError).whenComplete(
            () => _activePresentations.remove(scope),
          ),
    );
    return completer.future;
  }

  static Future<WisperBotChatResult?> _openPresentation(
    BuildContext context, {
    required String scope,
    required WisperBotConfig config,
    required WisperBotChatController? suppliedController,
    required WisperBotPresentation presentation,
  }) async {
    WisperBotClient? ownedClient;
    final controller = suppliedController ??
        (() {
          final client = WisperBotClient(config: config);
          ownedClient = client;
          return WisperBotChatController(client: client);
        })();
    if (ownedClient != null) _ownedControllers[scope] = controller;

    try {
      switch (presentation) {
        case WisperBotPresentation.fullScreen:
          await Navigator.of(context).push<WisperBotChatResult>(
            MaterialPageRoute<WisperBotChatResult>(
              builder: (_) => WisperBotChatScreen(
                config: config,
                controller: controller,
              ),
            ),
          );
          break;
        case WisperBotPresentation.bottomSheet:
          controller.handlePresentationOpened();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: FractionallySizedBox(
                key: const ValueKey<String>('wisperbot-bottom-sheet'),
                heightFactor: 0.96,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Material(
                    child: WisperBotChatView(
                      config: config,
                      controller: controller,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(
            WisperBotChatCloseReason.userClosed,
          );
          break;
        case WisperBotPresentation.dialog:
          controller.handlePresentationOpened();
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 720,
                ),
                child: SizedBox(
                  width: 420,
                  height: MediaQuery.sizeOf(dialogContext).height * 0.82,
                  child: WisperBotChatView(
                    config: config,
                    controller: controller,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(
            WisperBotChatCloseReason.userClosed,
          );
          break;
      }
      return const WisperBotChatResult(
        reason: WisperBotChatCloseReason.userClosed,
      );
    } finally {
      if (ownedClient != null) {
        _ownedControllers.remove(scope);
        await controller.dispose();
        await ownedClient!.close();
      }
    }
  }

  /// Deletes credentials for [config] and resets any facade-owned controller.
  ///
  /// Throws [WisperBotException] when configuration or secure storage fails.
  static Future<void> resetSession({required WisperBotConfig config}) async {
    validateWisperBotRuntimeConfig(config);
    final scope = wisperBotPresentationScope(config);
    final active = _ownedControllers[scope];
    if (active != null) {
      await active.resetSession();
      return;
    }

    await resetWisperBotStoredSession(config);
  }
}
