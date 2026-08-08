import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
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

/// Floating launcher that initializes chat and opens one presentation per scope.
class WisperBotChatLauncher extends StatefulWidget {
  /// Creates a launcher.
  ///
  /// When [controller] is omitted, the launcher owns and disposes its runtime.
  const WisperBotChatLauncher({
    super.key,
    required this.config,
    this.controller,
    this.alignment,
    this.margin,
    this.presentation,
    this.builder,
  });

  /// Widget and visitor configuration.
  final WisperBotConfig config;

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
  WisperBotClient? _ownedClient;
  StreamSubscription<WisperBotChatState>? _subscription;
  late WisperBotChatState _state;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied == null) {
      final client = WisperBotClient(config: widget.config);
      _ownedClient = client;
      _controller = WisperBotChatController(client: client);
    } else {
      _controller = supplied;
    }
    _state = _controller.state;
    _subscription = _controller.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    unawaited(_controller.initialize().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final open = _opening ? () {} : () => unawaited(_open());
    final custom = widget.builder;
    if (custom != null) return custom(context, _state, open);

    final isConfigurationLoaded = _state.widget != null;
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
      override: widget.config.theme,
      useApiColors: widget.config.useApiColors,
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
        config: widget.config,
        controller: _controller,
        presentation: widget.presentation,
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
