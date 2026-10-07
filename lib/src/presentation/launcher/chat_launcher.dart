import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';
import '../facade/wisperbot_chat.dart';
import '../media/remote_image.dart';
import '../theme/resolved_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/unread_badge.dart';

/// Builds a custom launcher from controller state and an idempotent open action.
typedef WisperBotLauncherBuilder = Widget Function(
  BuildContext context,
  WisperBotChatState state,
  VoidCallback openChat,
);

/// Builds custom content for an unread badge from the current unread count.
typedef WisperBotBadgeLabelBuilder = Widget Function(
  BuildContext context,
  int unreadCount,
);

/// Floating launcher that preloads configuration and opens one presentation.
class WisperBotChatLauncher extends StatefulWidget {
  /// Creates a launcher.
  ///
  /// When [controller] is omitted, the initialized shared runtime is used.
  /// The default launcher displays an unread dot until chat is viewed.
  const WisperBotChatLauncher({
    super.key,
    this.controller,
    this.alignment,
    this.margin,
    this.presentation,
    this.builder,
    this.showBadge = true,
    this.badgeShowCount = false,
    this.badgeMaxCount = 99,
    this.badgeLabelBuilder,
    this.badgeBackgroundColor,
    this.badgeTextColor,
    this.badgeSmallSize = 14,
    this.badgeLargeSize,
    this.badgeTextStyle,
    this.badgePadding,
    this.badgeAlignment,
    this.badgeOffset = const Offset(1, -1),
  });

  /// Optional host-owned controller.
  final WisperBotChatController? controller;

  /// Optional alignment overriding the server launcher position.
  final Alignment? alignment;

  /// Insets around the floating launcher.
  final EdgeInsetsGeometry? margin;

  /// Presentation style used when tapped.
  final WisperBotPresentation? presentation;

  /// Optional custom launcher renderer.
  final WisperBotLauncherBuilder? builder;

  /// Whether the default launcher displays unread state. Defaults to true.
  final bool showBadge;

  /// Whether the badge displays its unread count instead of a dot.
  ///
  /// One- and two-digit counts are circular. Overflow and custom labels use a
  /// pill shape.
  final bool badgeShowCount;

  /// Largest count displayed before the badge uses a plus suffix.
  final int badgeMaxCount;

  /// Optional custom unread badge label, built from the current count.
  final WisperBotBadgeLabelBuilder? badgeLabelBuilder;

  /// Optional unread badge fill color.
  final Color? badgeBackgroundColor;

  /// Optional unread badge label color.
  final Color? badgeTextColor;

  /// Diameter of a dot badge.
  final double? badgeSmallSize;

  /// Height of a badge with label content.
  ///
  /// This is also the diameter of normal one- and two-digit count badges.
  final double? badgeLargeSize;

  /// Optional unread badge label style.
  final TextStyle? badgeTextStyle;

  /// Padding around overflow or custom unread badge label content.
  final EdgeInsetsGeometry? badgePadding;

  /// Alignment of the badge relative to the launcher.
  ///
  /// Defaults to the logical top end.
  final AlignmentGeometry? badgeAlignment;

  /// Fine positioning adjustment after alignment.
  ///
  /// Positive x moves right and positive y moves down.
  final Offset? badgeOffset;

  @override
  State<WisperBotChatLauncher> createState() => _WisperBotChatLauncherState();
}

class _WisperBotChatLauncherState extends State<WisperBotChatLauncher> {
  late WisperBotChatController _controller;
  StreamSubscription<WisperBotChatState>? _subscription;
  late WisperBotChatState _state;
  bool _opening = false;
  bool _configurationPending = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied != null) {
      _controller = supplied;
    } else {
      _controller = WisperBotChat.requireDefaultController();
    }
    _state = _controller.state;
    _subscription = _controller.states.listen((state) {
      if (!mounted) return;
      _state = state;
      if (SchedulerBinding.instance.schedulerPhase ==
          SchedulerPhase.persistentCallbacks) {
        // A shared chat view can initialize while its route is building.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        setState(() {});
      }
    });
    _configurationPending = _state.widget == null;
    unawaited(_loadConfiguration());
  }

  Future<void> _loadConfiguration() async {
    try {
      await _controller.loadConfiguration();
    } on Object {
      // The fallback launcher remains usable when configuration cannot load.
    } finally {
      if (mounted) setState(() => _configurationPending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = _opening ? () {} : () => unawaited(_open());
    final custom = widget.builder;
    if (custom != null) return custom(context, _state, open);

    final isConfigurationLoaded =
        _state.widget != null || !_configurationPending;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (!isConfigurationLoaded) return const SizedBox.shrink();
      return _buildPositionedLauncher(
        context,
        child: _buildDefaultLauncherButton(context, open),
      );
    }

    return _buildPositionedLauncher(
      context,
      child: AnimatedSwitcher(
        key: const ValueKey<String>('wisperbot-launcher-transition'),
        duration: const Duration(milliseconds: 140),
        transitionBuilder: _buildZoomTransition,
        child: isConfigurationLoaded
            ? KeyedSubtree(
                key: const ValueKey<String>('wisperbot-launcher-loaded'),
                child: _buildDefaultLauncherButton(context, open),
              )
            : const SizedBox.shrink(
                key: ValueKey<String>('wisperbot-launcher-loading'),
              ),
      ),
    );
  }

  Widget _buildPositionedLauncher(
    BuildContext context, {
    required Widget child,
  }) =>
      Align(
        alignment: widget.alignment ?? _serverAlignment(_state),
        child: SafeArea(
          minimum: (widget.margin ?? const EdgeInsets.all(16))
              .resolve(Directionality.of(context)),
          child: child,
        ),
      );

  Widget _buildDefaultLauncherButton(
    BuildContext context,
    VoidCallback open,
  ) {
    final colors = WisperBotResolvedTheme.resolve(
      hostTheme: Theme.of(context),
      server: _state.widget,
      override: _controller.runtimeTheme,
      useApiColors: _controller.runtimeUseApiColors,
    );
    const label = 'Open chat';
    final button = FloatingActionButton(
      heroTag: null,
      tooltip: label,
      onPressed: open,
      backgroundColor: colors.primary,
      foregroundColor: colors.onPrimary,
      child: _launcherIcon(_state, colors.launcherSize),
    );
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: colors.launcherSize,
        child: _buildUnreadBadge(context, colors, button),
      ),
    );
  }

  Widget _buildUnreadBadge(
    BuildContext context,
    WisperBotResolvedTheme colors,
    Widget child,
  ) {
    if (!widget.showBadge) return child;
    final unreadCount = _state.unreadCount;
    return WisperBotUnreadBadgeView(
      unreadCount: unreadCount,
      indicatorKey: const ValueKey<String>('wisperbot-unread-indicator'),
      showCount: widget.badgeShowCount,
      maxCount: widget.badgeMaxCount,
      labelBuilder: widget.badgeLabelBuilder,
      backgroundColor: widget.badgeBackgroundColor ?? colors.error,
      textColor: widget.badgeTextColor,
      smallSize: widget.badgeSmallSize,
      largeSize: widget.badgeLargeSize,
      textStyle: widget.badgeTextStyle,
      padding: widget.badgePadding,
      alignment: widget.badgeAlignment,
      offset: widget.badgeOffset,
      child: child,
    );
  }

  Widget _buildZoomTransition(
    Widget child,
    Animation<double> animation,
  ) {
    final scale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
    );
    return ScaleTransition(
      key: child.key == const ValueKey<String>('wisperbot-launcher-loaded')
          ? const ValueKey<String>('wisperbot-launcher-zoom')
          : null,
      scale: scale,
      alignment: Alignment.center,
      child: child,
    );
  }

  Widget _launcherIcon(WisperBotChatState state, double launcherSize) {
    final logo = state.widget?.launcherLogoUrl;
    return SizedBox.square(
      dimension: launcherSize * 4 / 7,
      child: logo == null
          ? _builtInLauncherLogo()
          : WisperBotRemoteImage(
              url: logo,
              fit: BoxFit.contain,
              errorBuilder: (_) => _builtInLauncherLogo(),
            ),
    );
  }

  Widget _builtInLauncherLogo() => const WisperBotBrandLogo(
        imageKey: ValueKey<String>('wisperbot-launcher-logo'),
      );

  Alignment _serverAlignment(WisperBotChatState state) =>
      state.widget?.launcherPosition == WisperBotLauncherPosition.bottomLeft
          ? Alignment.bottomLeft
          : Alignment.bottomRight;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await WisperBotChat.open(
        context,
        controller: _controller,
        presentation: widget.presentation,
      );
    } on WisperBotException catch (error) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
