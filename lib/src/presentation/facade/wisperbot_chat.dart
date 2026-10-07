import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/services/widget_onesignal_service.dart';
import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../domain/contracts/media_adapter.dart';
import '../../domain/contracts/session_store.dart';
import '../../domain/entities/wisperbot_user.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/events/chat_event.dart';
import '../../domain/models/models.dart';
import '../screen/chat_screen.dart';
import '../view/chat_view.dart';
import '../launcher/chat_launcher.dart';
import '../widgets/unread_badge.dart';

/// Static entry point for the default WisperBot runtime and modal chat UI.
abstract final class WisperBotChat {
  static final Map<String, Future<WisperBotChatResult?>> _activePresentations =
      <String, Future<WisperBotChatResult?>>{};

  static WisperBotConfig? _defaultConfig;
  static WisperBotClient? _defaultClient;
  static WisperBotChatController? _defaultController;
  static Future<void>? _initializing;
  static StreamSubscription<Map<String, dynamic>>?
      _notificationClickSubscription;
  static StreamSubscription<Map<String, dynamic>>?
      _foregroundNotificationSubscription;
  static StreamSubscription<WisperBotChatState>? _runtimeStateSubscription;
  static final ValueNotifier<int> _unreadCount = ValueNotifier<int>(0);
  static void Function(Map<String, dynamic> payload)? _onNotificationTapped;
  static void Function(Map<String, dynamic> payload)? _onForegroundNotification;
  static Map<String, dynamic>? _pendingNotificationPayload;
  static GlobalKey<NavigatorState>? _navigatorKey;
  static int _lifecycleGeneration = 0;
  static int _registrationGeneration = 0;

  /// Initializes the shared default runtime.
  ///
  /// Repeating this call with the same options is safe and refreshes the
  /// navigator and callbacks. Different options require [shutdown] first.
  static Future<void> initialize({
    required String widgetKey,
    String apiBaseUrl = 'https://wisperbot.com',
    WisperBotThemeData? theme,
    bool useApiColors = true,
    bool lightStatusBarIcons = false,
    WisperBotPresentation presentation = WisperBotPresentation.fullScreen,
    bool enableTyping = true,
    WisperBotMediaAdapter? mediaAdapter,
    WisperBotDiagnosticsCallback? diagnostics,
    String? oneSignalAppId,
    bool enableOneSignal = true,
    bool requireNotificationPermission = true,
    bool registerVisitorOnAppLaunch = true,
    WisperBotSessionStore? sessionStore,
    GlobalKey<NavigatorState>? navigatorKey,
    void Function(Map<String, dynamic> payload)? onNotificationTapped,
    void Function(Map<String, dynamic> payload)? onForegroundNotification,
  }) {
    final config = WisperBotConfig(
      widgetKey: widgetKey,
      apiBaseUrl: apiBaseUrl,
      theme: theme,
      useApiColors: useApiColors,
      lightStatusBarIcons: lightStatusBarIcons,
      presentation: presentation,
      enableTyping: enableTyping,
      mediaAdapter: mediaAdapter,
      diagnostics: diagnostics,
      oneSignalAppId: oneSignalAppId,
      enableOneSignal: enableOneSignal,
      requireNotificationPermission: requireNotificationPermission,
      registerVisitorOnAppLaunch: registerVisitorOnAppLaunch,
      sessionStore: sessionStore,
    );
    validateWisperBotRuntimeConfig(config);
    final existingConfig = _defaultConfig;
    if (existingConfig != null && !_sameConfiguration(existingConfig, config)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'WisperBotChat is already initialized. Call shutdown() before initializing with a different configuration.',
        retryable: false,
      );
    }

    _navigatorKey = navigatorKey ?? _navigatorKey;
    _onNotificationTapped = onNotificationTapped;
    _onForegroundNotification = onForegroundNotification;

    final active = _initializing;
    if (active != null) return active;
    if (existingConfig != null) {
      _schedulePendingNotificationOpen();
      return Future<void>.value();
    }

    final client = WisperBotClient.fromConfig(config: config);
    _defaultConfig = config;
    _defaultClient = client;
    _defaultController = WisperBotChatController(client: client);
    _runtimeStateSubscription = _defaultController!.states.listen((state) {
      _publishUnreadCount(state.unreadCount);
    });

    final generation = ++_lifecycleGeneration;
    final future = _initializeRuntime(config, generation);
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  static Future<void> _initializeRuntime(
    WisperBotConfig config,
    int generation,
  ) async {
    final appId = config.oneSignalAppId;
    if (config.enableOneSignal && appId != null && appId.trim().isNotEmpty) {
      await WidgetOneSignalService.instance.initialize(appId: appId);
    }
    if (generation != _lifecycleGeneration || _defaultConfig == null) return;

    await _notificationClickSubscription?.cancel();
    _notificationClickSubscription = WidgetOneSignalService
        .instance.notificationClicks
        .listen(_handleNotificationClick);
    await _foregroundNotificationSubscription?.cancel();
    _foregroundNotificationSubscription = WidgetOneSignalService
        .instance.foregroundNotifications
        .listen(_handleForegroundNotification);

    if (config.registerVisitorOnAppLaunch) {
      _scheduleLaunchRegistration();
    }
    _schedulePendingNotificationOpen();
  }

  static void _scheduleLaunchRegistration() {
    final generation = ++_registrationGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _registrationGeneration) return;
      final config = _defaultConfig;
      final controller = _defaultController;
      if (config == null ||
          controller == null ||
          !config.registerVisitorOnAppLaunch) {
        return;
      }
      unawaited(controller.initialize().catchError((_) {}));
    });
  }

  /// Sets the visitor identity for the shared runtime.
  static Future<void> identify(WisperBotUser user) async {
    validateWisperBotRuntimeUser(user);
    final config = _requireDefaultConfig();
    final controller = requireDefaultController();
    _registrationGeneration++;
    await controller.updateUser(
      user,
      startSession: config.registerVisitorOnAppLaunch ||
          controller.state.phase != WisperBotChatPhase.idle,
    );
  }

  /// Logs out the shared visitor and clears that identity's session.
  static Future<void> logout() async {
    _registrationGeneration++;
    await requireDefaultController().updateUser(null, startSession: false);
  }

  /// Unread agent-message count for host-owned launcher buttons.
  ///
  /// Listen with [ValueListenableBuilder] and show a badge when the value is
  /// greater than zero. Opening the shared chat marks those messages as read.
  static ValueListenable<int> get unreadCount => _unreadCount;

  static void _publishUnreadCount(int count) {
    if (_unreadCount.value == count) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      final generation = _lifecycleGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (generation == _lifecycleGeneration && _defaultController != null) {
          _unreadCount.value = count;
        }
      });
      return;
    }
    _unreadCount.value = count;
  }

  /// Adds an unread indicator to any host-owned widget.
  ///
  /// By default this renders a dot. Set [showCount] to display the unread
  /// count, or provide [labelBuilder] for a fully custom label.
  static Widget badge({
    Key? key,
    required Widget child,
    bool showCount = false,
    int maxCount = 99,
    Widget Function(BuildContext context, int unreadCount)? labelBuilder,
    Color? backgroundColor,
    Color? textColor,
    double? smallSize = 8,
    double? largeSize,
    TextStyle? textStyle,
    EdgeInsetsGeometry? padding,
    AlignmentGeometry? alignment,
    Offset? offset,
  }) =>
      _WisperBotUnreadBadge(
        key: key,
        showCount: showCount,
        maxCount: maxCount,
        labelBuilder: labelBuilder,
        backgroundColor: backgroundColor,
        textColor: textColor,
        smallSize: smallSize,
        largeSize: largeSize,
        textStyle: textStyle,
        padding: padding,
        alignment: alignment,
        offset: offset,
        child: child,
      );

  /// Creates a floating launcher backed by the shared runtime.
  static WisperBotChatLauncher launcher({
    Key? key,
    Alignment? alignment,
    EdgeInsetsGeometry? margin,
    WisperBotPresentation? presentation,
    WisperBotLauncherBuilder? builder,
    bool showBadge = true,
    bool badgeShowCount = false,
    int badgeMaxCount = 99,
    WisperBotBadgeLabelBuilder? badgeLabelBuilder,
    Color? badgeBackgroundColor,
    Color? badgeTextColor,
    double? badgeSmallSize = 14,
    double? badgeLargeSize,
    TextStyle? badgeTextStyle,
    EdgeInsetsGeometry? badgePadding,
    AlignmentGeometry? badgeAlignment,
    Offset? badgeOffset = const Offset(1, -1),
  }) =>
      WisperBotChatLauncher(
        key: key,
        alignment: alignment,
        margin: margin,
        presentation: presentation,
        builder: builder,
        showBadge: showBadge,
        badgeShowCount: badgeShowCount,
        badgeMaxCount: badgeMaxCount,
        badgeLabelBuilder: badgeLabelBuilder,
        badgeBackgroundColor: badgeBackgroundColor,
        badgeTextColor: badgeTextColor,
        badgeSmallSize: badgeSmallSize,
        badgeLargeSize: badgeLargeSize,
        badgeTextStyle: badgeTextStyle,
        badgePadding: badgePadding,
        badgeAlignment: badgeAlignment,
        badgeOffset: badgeOffset,
      );

  /// Creates an embeddable chat view backed by the shared runtime.
  static WisperBotChatView view({
    Key? key,
    bool showHeader = true,
    WisperBotChatStateBuilder? emptyBuilder,
    WisperBotChatStateBuilder? errorBuilder,
    WisperBotMessageBuilder? messageBuilder,
    WisperBotComposerBuilder? composerBuilder,
    VoidCallback? onClose,
  }) =>
      WisperBotChatView(
        key: key,
        showHeader: showHeader,
        emptyBuilder: emptyBuilder,
        errorBuilder: errorBuilder,
        messageBuilder: messageBuilder,
        composerBuilder: composerBuilder,
        onClose: onClose,
      );

  /// Creates a full-screen chat scaffold backed by the shared runtime.
  static WisperBotChatScreen screen({
    Key? key,
    PreferredSizeWidget? appBar,
    ValueChanged<WisperBotChatCloseReason>? onClosed,
  }) =>
      WisperBotChatScreen(
        key: key,
        appBar: appBar,
        onClosed: onClosed,
      );

  /// Releases the shared runtime without deleting persisted session data.
  static Future<void> shutdown() async {
    _lifecycleGeneration++;
    _registrationGeneration++;
    await _notificationClickSubscription?.cancel();
    await _foregroundNotificationSubscription?.cancel();
    await _runtimeStateSubscription?.cancel();
    _notificationClickSubscription = null;
    _foregroundNotificationSubscription = null;
    _runtimeStateSubscription = null;
    _unreadCount.value = 0;

    final controller = _defaultController;
    final client = _defaultClient;
    _defaultController = null;
    _defaultClient = null;
    _defaultConfig = null;
    _initializing = null;
    _navigatorKey = null;
    _onNotificationTapped = null;
    _onForegroundNotification = null;
    _pendingNotificationPayload = null;
    _activePresentations.clear();

    if (controller != null) await controller.dispose();
    if (client != null) await client.close();
  }

  /// Opens the chatbox associated with a tapped notification.
  static Future<WisperBotChatResult?> openChatboxFromNotification({
    BuildContext? context,
    WisperBotChatController? controller,
    Map<String, dynamic>? payload,
  }) {
    final effectiveContext = context ?? _navigatorKey?.currentContext;
    if (effectiveContext == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'No BuildContext or navigatorKey is available to open chat.',
        retryable: false,
      );
    }
    return open(
      effectiveContext,
      controller: controller,
    );
  }

  static void _handleNotificationClick(Map<String, dynamic> payload) {
    final callback = _onNotificationTapped;
    if (callback != null) {
      callback(payload);
      return;
    }
    if (_defaultConfig == null) return;
    final context = _navigatorKey?.currentContext;
    if (context == null) {
      _pendingNotificationPayload = payload;
      _schedulePendingNotificationOpen();
      return;
    }
    unawaited(
      openChatboxFromNotification(context: context, payload: payload)
          .catchError((_) => null),
    );
  }

  static void _handleForegroundNotification(Map<String, dynamic> payload) {
    _onForegroundNotification?.call(payload);
  }

  static void _schedulePendingNotificationOpen() {
    if (_pendingNotificationPayload == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final payload = _pendingNotificationPayload;
      final context = _navigatorKey?.currentContext;
      if (payload == null || context == null || _defaultConfig == null) return;
      _pendingNotificationPayload = null;
      unawaited(
        openChatboxFromNotification(context: context, payload: payload)
            .catchError((_) => null),
      );
    });
  }

  /// Opens at most one chat presentation for the selected runtime.
  ///
  /// With no [controller], the initialized shared runtime is used. Supplying a
  /// controller uses that caller-owned advanced runtime.
  static Future<WisperBotChatResult?> open(
    BuildContext context, {
    WisperBotChatController? controller,
    WisperBotPresentation? presentation,
  }) {
    final effectiveController = controller ?? requireDefaultController();
    final scope = effectiveController.runtimePresentationScope;
    final active = _activePresentations[scope];
    if (active != null) return active;

    final completer = Completer<WisperBotChatResult?>();
    _activePresentations[scope] = completer.future;
    unawaited(
      _openPresentation(
        context,
        controller: effectiveController,
        presentation: presentation ?? effectiveController.runtimePresentation,
      ).then(completer.complete, onError: completer.completeError).whenComplete(
            () => _activePresentations.remove(scope),
          ),
    );
    return completer.future;
  }

  static Future<WisperBotChatResult?> _openPresentation(
    BuildContext context, {
    required WisperBotChatController controller,
    required WisperBotPresentation presentation,
  }) async {
    try {
      await controller.ensureRuntimeChatPermission();
    } on WisperBotException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text(error.message),
            action: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: () async {
                      await launchUrl(Uri.parse('app-settings:'));
                    },
                  )
                : null,
          ),
        );
      }
      return null;
    }
    if (!context.mounted) return null;

    switch (presentation) {
      case WisperBotPresentation.fullScreen:
        await Navigator.of(context).push<WisperBotChatResult>(
          MaterialPageRoute<WisperBotChatResult>(
            builder: (_) => WisperBotChatScreen(controller: controller),
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
                child: ScaffoldMessenger(
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    body: WisperBotChatView(
                      controller: controller,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
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
                child: ScaffoldMessenger(
                  child: Scaffold(
                    resizeToAvoidBottomInset: false,
                    body: WisperBotChatView(
                      controller: controller,
                      onClose: () => Navigator.of(dialogContext).pop(),
                    ),
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
    }
    return const WisperBotChatResult(
      reason: WisperBotChatCloseReason.userClosed,
    );
  }

  /// Clears the active shared session.
  static Future<void> resetSession() =>
      requireDefaultController().resetSession();

  static WisperBotConfig _requireDefaultConfig() {
    final config = _defaultConfig;
    if (config == null) throw _notInitialized();
    return config;
  }

  /// Returns the shared controller for package-owned UI surfaces.
  @internal
  static WisperBotChatController requireDefaultController() {
    final controller = _defaultController;
    if (controller == null) throw _notInitialized();
    return controller;
  }

  static WisperBotException _notInitialized() => const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'Call WisperBotChat.initialize() before using the default runtime.',
        retryable: false,
      );

  static bool _sameConfiguration(
    WisperBotConfig first,
    WisperBotConfig second,
  ) =>
      first.widgetKey == second.widgetKey &&
      first.apiBaseUrl == second.apiBaseUrl &&
      identical(first.theme, second.theme) &&
      first.useApiColors == second.useApiColors &&
      first.lightStatusBarIcons == second.lightStatusBarIcons &&
      first.presentation == second.presentation &&
      first.enableTyping == second.enableTyping &&
      identical(first.mediaAdapter, second.mediaAdapter) &&
      identical(first.diagnostics, second.diagnostics) &&
      first.oneSignalAppId == second.oneSignalAppId &&
      first.enableOneSignal == second.enableOneSignal &&
      first.requireNotificationPermission ==
          second.requireNotificationPermission &&
      first.registerVisitorOnAppLaunch == second.registerVisitorOnAppLaunch &&
      identical(first.sessionStore, second.sessionStore);

  @visibleForTesting
  static void resetForTesting() {
    final controller = _defaultController;
    final client = _defaultClient;
    _lifecycleGeneration++;
    _registrationGeneration++;
    unawaited(_notificationClickSubscription?.cancel());
    unawaited(_foregroundNotificationSubscription?.cancel());
    unawaited(_runtimeStateSubscription?.cancel());
    if (controller != null) {
      unawaited(controller.dispose().whenComplete(() => client?.close()));
    } else if (client != null) {
      unawaited(client.close());
    }
    _defaultConfig = null;
    _defaultClient = null;
    _defaultController = null;
    _initializing = null;
    _notificationClickSubscription = null;
    _foregroundNotificationSubscription = null;
    _runtimeStateSubscription = null;
    _unreadCount.value = 0;
    _onNotificationTapped = null;
    _onForegroundNotification = null;
    _pendingNotificationPayload = null;
    _navigatorKey = null;
    _activePresentations.clear();
  }
}

class _WisperBotUnreadBadge extends StatelessWidget {
  const _WisperBotUnreadBadge({
    super.key,
    required this.child,
    required this.showCount,
    required this.maxCount,
    required this.labelBuilder,
    required this.backgroundColor,
    required this.textColor,
    required this.smallSize,
    required this.largeSize,
    required this.textStyle,
    required this.padding,
    required this.alignment,
    required this.offset,
  });

  final Widget child;
  final bool showCount;
  final int maxCount;
  final Widget Function(BuildContext context, int unreadCount)? labelBuilder;
  final Color? backgroundColor;
  final Color? textColor;
  final double? smallSize;
  final double? largeSize;
  final TextStyle? textStyle;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final Offset? offset;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: WisperBotChat.unreadCount,
        child: child,
        builder: (context, unreadCount, child) => WisperBotUnreadBadgeView(
          unreadCount: unreadCount,
          indicatorKey: const ValueKey<String>(
            'wisperbot-unread-badge-indicator',
          ),
          showCount: showCount,
          maxCount: maxCount,
          labelBuilder: labelBuilder,
          backgroundColor: backgroundColor,
          textColor: textColor,
          smallSize: smallSize,
          largeSize: largeSize,
          textStyle: textStyle,
          padding: padding,
          alignment: alignment,
          offset: offset,
          child: child!,
        ),
      );
}
