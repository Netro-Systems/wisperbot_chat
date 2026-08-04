import 'dart:async';

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import '../domain/models.dart';
import 'brand_logo.dart';
import 'facade.dart';
import 'remote_image.dart';
import 'resolved_theme.dart';

typedef WisperBotLauncherBuilder = Widget Function(
  BuildContext context,
  WisperBotChatState state,
  VoidCallback openChat,
);

class WisperBotChatLauncher extends StatefulWidget {
  const WisperBotChatLauncher({
    super.key,
    required this.config,
    this.controller,
    this.alignment,
    this.margin,
    this.presentation,
    this.builder,
  });

  final WisperBotConfig config;
  final WisperBotChatController? controller;
  final Alignment? alignment;
  final EdgeInsetsGeometry? margin;
  final WisperBotPresentation? presentation;
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
    final unread = _state.unreadCount;
    final label = unread != null && unread > 0
        ? 'Open chat, $unread unread ${unread == 1 ? 'message' : 'messages'}'
        : 'Open chat';
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
            if (unread != null && unread > 0)
              PositionedDirectional(
                top: -6,
                end: -6,
                child: _UnreadBadge(count: unread),
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

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.surface,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          count > 99 ? '99+' : '$count',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onError,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}
