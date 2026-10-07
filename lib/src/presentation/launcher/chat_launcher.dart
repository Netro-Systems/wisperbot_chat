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

/// Builds a custom launcher from controller state and an idempotent open action.
typedef WisperBotLauncherBuilder = Widget Function(
  BuildContext context,
  WisperBotChatState state,
  VoidCallback openChat,
);

/// Floating launcher that preloads configuration and opens one presentation.
class WisperBotChatLauncher extends StatefulWidget {
  /// Creates a launcher.
  ///
  /// When [controller] is omitted, the initialized shared runtime is used.
  const WisperBotChatLauncher({
    super.key,
    this.controller,
    this.alignment,
    this.margin,
    this.presentation,
    this.builder,
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
    return Semantics(
      button: true,
      label: label,
      child: SizedBox.square(
        dimension: colors.launcherSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: FloatingActionButton(
                heroTag: null,
                tooltip: label,
                onPressed: open,
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: _launcherIcon(_state, colors.launcherSize),
              ),
            ),
          ],
        ),
      ),
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
