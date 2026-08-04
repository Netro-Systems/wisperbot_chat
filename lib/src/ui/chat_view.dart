import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import '../domain/errors.dart';
import '../domain/media_adapter.dart';
import '../domain/models.dart';
import 'brand_logo.dart';
import 'remote_image.dart';
import 'resolved_theme.dart';

typedef WisperBotChatStateBuilder = Widget Function(
  BuildContext context,
  WisperBotChatState state,
);

typedef WisperBotMessageBuilder = Widget Function(
  BuildContext context,
  WisperBotMessage message,
);

typedef WisperBotComposerBuilder = Widget Function(
  BuildContext context,
  WisperBotChatController controller,
  WisperBotChatState state,
);

class WisperBotChatView extends StatefulWidget {
  const WisperBotChatView({
    super.key,
    required this.config,
    this.controller,
    this.showHeader = true,
    this.emptyBuilder,
    this.errorBuilder,
    this.messageBuilder,
    this.composerBuilder,
    this.onClose,
  });

  final WisperBotConfig config;
  final WisperBotChatController? controller;
  final bool showHeader;
  final WisperBotChatStateBuilder? emptyBuilder;
  final WisperBotChatStateBuilder? errorBuilder;
  final WisperBotMessageBuilder? messageBuilder;
  final WisperBotComposerBuilder? composerBuilder;
  final VoidCallback? onClose;

  @override
  State<WisperBotChatView> createState() => _WisperBotChatViewState();
}

class _WisperBotChatViewState extends State<WisperBotChatView> {
  final ScrollController _scrollController = ScrollController();
  late WisperBotChatController _controller;
  WisperBotClient? _ownedClient;
  StreamSubscription<WisperBotChatState>? _subscription;
  late WisperBotChatState _state;
  bool _nearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_trackScrollPosition);
    _attachRuntime();
  }

  @override
  void didUpdateWidget(covariant WisperBotChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.config, widget.config)) {
      unawaited(_replaceRuntime());
    }
  }

  void _attachRuntime() {
    final supplied = widget.controller;
    if (supplied == null) {
      final client = WisperBotClient(config: widget.config);
      _ownedClient = client;
      _controller = WisperBotChatController(client: client);
    } else {
      _controller = supplied;
    }
    _state = _controller.state;
    _subscription = _controller.states.listen(_onState);
    unawaited(_controller.initialize().catchError((_) {}));
  }

  Future<void> _replaceRuntime() async {
    await _subscription?.cancel();
    final oldClient = _ownedClient;
    if (oldClient != null) {
      await _controller.dispose();
      await oldClient.close();
    }
    _ownedClient = null;
    if (!mounted) return;
    _attachRuntime();
    setState(() {});
  }

  void _onState(WisperBotChatState next) {
    if (!mounted) return;
    final grew = next.messages.length > _state.messages.length;
    final sentByVisitor = grew &&
        next.messages.isNotEmpty &&
        next.messages.last.role == WisperBotMessageRole.visitor;
    setState(() => _state = next);
    if (grew && (_nearBottom || sentByVisitor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _trackScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _nearBottom = position.maxScrollExtent - position.pixels < 96;
  }

  void _scrollToEnd() {
    if (!mounted || !_scrollController.hasClients) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = _scrollController.position.maxScrollExtent;
    if (reduceMotion) {
      _scrollController.jumpTo(target);
    } else {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostTheme = Theme.of(context);
    final colors = WisperBotResolvedTheme.resolve(
      hostTheme: hostTheme,
      server: _state.widget,
      override: widget.config.theme,
      useApiColors: widget.config.useApiColors,
    );
    final sdkTheme = hostTheme.copyWith(
      colorScheme: hostTheme.colorScheme.copyWith(
        primary: colors.primary,
        onPrimary: colors.onPrimary,
      ),
      textSelectionTheme: hostTheme.textSelectionTheme.copyWith(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.24),
        selectionHandleColor: colors.primary,
      ),
    );
    return Theme(
      data: sdkTheme,
      child: ColoredBox(
        color: colors.background,
        child: _isLoading(_state.phase)
            ? _ChatLoadingShimmer(showHeader: widget.showHeader)
            : Column(
                children: <Widget>[
                  if (widget.showHeader)
                    _ChatHeader(
                      state: _state,
                      colors: colors,
                      onClose: widget.onClose,
                    ),
                  if (_state.phase == WisperBotChatPhase.reconnecting)
                    _ConnectionBanner(colors: colors),
                  if (_state.supportAvailability ==
                      WisperBotSupportAvailability.unavailable)
                    _AvailabilityBanner(state: _state, colors: colors),
                  Expanded(child: _buildBody(colors)),
                  if (_canCompose(_state)) _buildComposer(colors),
                ],
              ),
      ),
    );
  }

  bool _isLoading(WisperBotChatPhase phase) =>
      phase == WisperBotChatPhase.idle ||
      phase == WisperBotChatPhase.initializing ||
      phase == WisperBotChatPhase.expired;

  Widget _buildBody(WisperBotResolvedTheme colors) {
    switch (_state.phase) {
      case WisperBotChatPhase.idle:
      case WisperBotChatPhase.initializing:
      case WisperBotChatPhase.expired:
        return const SizedBox.shrink();
      case WisperBotChatPhase.failure:
      case WisperBotChatPhase.awaitingPreChat:
        return widget.errorBuilder?.call(context, _state) ??
            _ErrorState(
              state: _state,
              colors: colors,
              onRetry: _state.error?.retryable == true
                  ? () => unawaited(
                        _controller.initialize().catchError((_) {}),
                      )
                  : null,
            );
      case WisperBotChatPhase.ready:
      case WisperBotChatPhase.reconnecting:
        if (_state.messages.isEmpty) {
          final custom = widget.emptyBuilder?.call(context, _state);
          if (custom != null) return custom;
        }
        return _timeline(colors);
      case WisperBotChatPhase.disposed:
        return const SizedBox.shrink();
    }
  }

  Widget _timeline(WisperBotResolvedTheme colors) {
    final configuredWelcome = _state.widget?.welcomeMessage.trim();
    final welcome = configuredWelcome?.isNotEmpty == true
        ? configuredWelcome!
        : 'Hi there! How can we help?';
    const welcomeCount = 1;
    final typingCount = _state.agentTyping == null ? 0 : 1;
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _controller.refresh,
      child: Stack(
        children: <Widget>[
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: welcomeCount + _state.messages.length + typingCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: colors.messageSpacing),
                  child: _WelcomeBubble(
                    body: welcome,
                    widgetConfig: _state.widget,
                    colors: colors,
                  ),
                );
              }
              final messageIndex = index - welcomeCount;
              if (messageIndex == _state.messages.length) {
                return _TypingIndicator(
                  typing: _state.agentTyping!,
                  colors: colors,
                );
              }
              final message = _state.messages[messageIndex];
              return Padding(
                padding: EdgeInsets.only(bottom: colors.messageSpacing),
                child: widget.messageBuilder?.call(context, message) ??
                    _MessageBubble(
                      message: message,
                      widgetConfig: _state.widget,
                      colors: colors,
                      onRetry:
                          message.status == WisperBotMessageStatus.failed &&
                                  message.error?.retryable == true
                              ? () => unawaited(
                                    _controller
                                        .retryMessage(message.localId)
                                        .catchError((_) => message),
                                  )
                              : null,
                      onRemove:
                          message.status == WisperBotMessageStatus.failed ||
                                  message.status ==
                                      WisperBotMessageStatus.unconfirmed
                              ? () => unawaited(
                                    _controller.removeMessage(message.localId),
                                  )
                              : null,
                      onRefresh:
                          message.status == WisperBotMessageStatus.unconfirmed
                              ? () => unawaited(
                                    _controller.refresh().catchError((_) {}),
                                  )
                              : null,
                    ),
              );
            },
          ),
          if (!_nearBottom)
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Jump to latest message',
                onPressed: _scrollToEnd,
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(WisperBotResolvedTheme colors) {
    final custom = widget.composerBuilder;
    if (custom != null) return custom(context, _controller, _state);
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HandoffAction(
              state: _state,
              colors: colors,
              onPressed: () => unawaited(
                _controller.requestHumanAgent().catchError((_) {}),
              ),
            ),
            _Composer(
              controller: _controller,
              colors: colors,
              mediaAdapter: widget.config.mediaAdapter,
              imagesEnabled: _state.capabilities.images,
              audioEnabled: _state.capabilities.audio,
            ),
            _BrandFooter(
              companyName: _state.widget?.footerCompanyName,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  bool _canCompose(WisperBotChatState state) =>
      state.phase == WisperBotChatPhase.ready ||
      state.phase == WisperBotChatPhase.reconnecting;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_trackScrollPosition)
      ..dispose();
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}

class _ChatLoadingShimmer extends StatefulWidget {
  const _ChatLoadingShimmer({required this.showHeader});

  final bool showHeader;

  @override
  State<_ChatLoadingShimmer> createState() => _ChatLoadingShimmerState();
}

class _ChatLoadingShimmerState extends State<_ChatLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF2B2F35) : const Color(0xFFE1E5EA);
    final highlight =
        isDark ? const Color(0xFF3A3F47) : const Color(0xFFF3F5F7);
    final canvas = isDark ? const Color(0xFF17191D) : const Color(0xFFF7F8FA);
    final skeleton = _LoadingSkeleton(showHeader: widget.showHeader);

    return ColoredBox(
      key: const ValueKey<String>('wisperbot-loading-canvas'),
      color: canvas,
      child: Semantics(
        key: const ValueKey<String>('wisperbot-loading-shimmer'),
        label: 'Connecting to chat',
        liveRegion: true,
        child: ExcludeSemantics(
          child: RepaintBoundary(
            child: reduceMotion
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(base, BlendMode.srcIn),
                    child: skeleton,
                  )
                : AnimatedBuilder(
                    animation: _controller,
                    child: skeleton,
                    builder: (context, child) {
                      final travel = (_controller.value * 3) - 1.5;
                      return ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (bounds) => LinearGradient(
                          begin: Alignment(travel - 1, 0),
                          end: Alignment(travel + 1, 0),
                          colors: <Color>[base, highlight, base],
                          stops: const <double>[0.2, 0.5, 0.8],
                        ).createShader(bounds),
                        child: child,
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton({required this.showHeader});

  final bool showHeader;

  @override
  Widget build(BuildContext context) => Column(
        children: <Widget>[
          if (showHeader)
            SafeArea(
              bottom: false,
              child: Column(
                children: <Widget>[
                  Padding(
                    key: const ValueKey<String>('wisperbot-loading-header'),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                    child: Row(
                      children: <Widget>[
                        const _ShimmerBlock.circle(size: 36),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const <Widget>[
                              FractionallySizedBox(
                                widthFactor: 0.42,
                                child: _ShimmerBlock(height: 13),
                              ),
                              SizedBox(height: 8),
                              FractionallySizedBox(
                                widthFactor: 0.62,
                                child: _ShimmerBlock(height: 9),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: _ShimmerBlock(
                      key: ValueKey<String>('wisperbot-loading-appbar-line'),
                      height: 3,
                      radius: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bottomSpacing = math.max(
                  28.0,
                  MediaQuery.viewPaddingOf(context).bottom + 12,
                );
                final composerHeight = bottomSpacing + 48;
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    if (constraints.maxHeight >= composerHeight + 96)
                      PositionedDirectional(
                        key: const ValueKey<String>(
                          'wisperbot-loading-message-1',
                        ),
                        start: 14,
                        top: 18,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.62),
                        height: 62,
                        child: const _ShimmerBlock(height: 62, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 154)
                      PositionedDirectional(
                        end: 14,
                        top: 94,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.48),
                        height: 44,
                        child: const _ShimmerBlock(height: 44, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 264)
                      PositionedDirectional(
                        start: 14,
                        top: 152,
                        width: math.max(0, (constraints.maxWidth - 28) * 0.72),
                        height: 76,
                        child: const _ShimmerBlock(height: 76, radius: 16),
                      ),
                    if (constraints.maxHeight >= composerHeight + 14)
                      PositionedDirectional(
                        key: const ValueKey<String>(
                          'wisperbot-loading-composer',
                        ),
                        start: 14,
                        end: 14,
                        bottom: bottomSpacing,
                        height: 48,
                        child: constraints.maxWidth >= 100
                            ? const Row(
                                children: <Widget>[
                                  Expanded(
                                    child: _ShimmerBlock(
                                      height: 48,
                                      radius: 24,
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  _ShimmerBlock.circle(size: 48),
                                ],
                              )
                            : const _ShimmerBlock(height: 48, radius: 24),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      );
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    super.key,
    required this.height,
    this.radius = 6,
  }) : width = null;

  const _ShimmerBlock.circle({required double size})
      : width = size,
        height = size,
        radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.state,
    required this.colors,
    required this.onClose,
  });

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final widgetConfig = state.widget;
    final title = widgetConfig?.title.trim().isNotEmpty == true
        ? widgetConfig!.title
        : 'Chat with us';
    final subtitle = _subtitle(state);
    return Material(
      key: const ValueKey<String>('wisperbot-chat-header'),
      color: colors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
          child: Row(
            children: <Widget>[
              _SupportAvatar(
                avatarUrl: widgetConfig?.avatarUrl,
                size: 36,
                backgroundColor: colors.onPrimary.withValues(alpha: 0.18),
                borderColor: colors.onPrimary.withValues(alpha: 0.62),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colors.onPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: state.supportAvailability ==
                                    WisperBotSupportAvailability.unavailable
                                ? colors.onPrimary.withValues(alpha: 0.45)
                                : const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color:
                                      colors.onPrimary.withValues(alpha: 0.92),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close chat',
                  onPressed: onClose,
                  color: colors.onPrimary,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(WisperBotChatState state) {
    if (state.connection == WisperBotConnectionState.reconnecting) {
      return 'Reconnecting…';
    }
    if (state.handoff.status == WisperBotHandoffStatus.connected) {
      return 'Connected to support';
    }
    final configured = state.widget?.subtitle.trim();
    return configured?.isNotEmpty == true ? configured! : 'We are here to help';
  }
}

class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.colors});

  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: colors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Reconnecting. New messages may not be confirmed yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _AvailabilityBanner extends StatelessWidget {
  const _AvailabilityBanner({required this.state, required this.colors});

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: colors.surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          state.widget?.offlineMessage?.trim().isNotEmpty == true
              ? state.widget!.offlineMessage!
              : 'Support is currently away. You can still leave a message.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}

class _WelcomeBubble extends StatelessWidget {
  const _WelcomeBubble({
    required this.body,
    required this.widgetConfig,
    required this.colors,
  });

  final String body;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Support welcome message. $body',
        child: _BubbleLayout(
          visitor: false,
          widgetConfig: widgetConfig,
          colors: colors,
          bubbleKey: const ValueKey<String>('wisperbot-welcome-bubble'),
          child: SelectableText(
            body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onAgentBubble,
                  height: 1.4,
                ),
          ),
        ),
      );
}

class _BubbleLayout extends StatelessWidget {
  const _BubbleLayout({
    required this.visitor,
    required this.widgetConfig,
    required this.colors,
    required this.child,
    this.bubbleKey,
  });

  final bool visitor;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;
  final Widget child;
  final Key? bubbleKey;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final maximumWidth = math.min(constraints.maxWidth * 0.76, 520.0);
          return Align(
            alignment: visitor
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maximumWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  if (!visitor) ...<Widget>[
                    _SupportAvatar(
                      avatarUrl: widgetConfig?.avatarUrl,
                      size: 28,
                      backgroundColor: colors.primary,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: DecoratedBox(
                      key: bubbleKey,
                      decoration: BoxDecoration(
                        color:
                            visitor ? colors.visitorBubble : colors.agentBubble,
                        border:
                            visitor ? null : Border.all(color: colors.outline),
                        borderRadius: BorderRadiusDirectional.only(
                          topStart: Radius.circular(colors.borderRadius),
                          topEnd: Radius.circular(colors.borderRadius),
                          bottomStart: Radius.circular(
                            visitor ? colors.borderRadius : 5,
                          ),
                          bottomEnd: Radius.circular(
                            visitor ? 5 : colors.borderRadius,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 9,
                        ),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _SupportAvatar extends StatelessWidget {
  const _SupportAvatar({
    required this.avatarUrl,
    required this.size,
    required this.backgroundColor,
    this.borderColor,
  });

  final Uri? avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final assetSize = size * 0.56;
    final fallback = Center(
      child: SizedBox.square(
        dimension: assetSize,
        child: const WisperBotBrandLogo(
          imageKey: ValueKey<String>('wisperbot-support-logo'),
        ),
      ),
    );
    return Semantics(
      label: 'Support avatar',
      image: true,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          border: borderColor == null
              ? null
              : Border.all(color: borderColor!, width: 2),
        ),
        child: avatarUrl == null
            ? fallback
            : Center(
                child: SizedBox.square(
                  dimension: assetSize,
                  child: WisperBotRemoteImage(
                    url: avatarUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (_) => fallback,
                  ),
                ),
              ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.state,
    required this.colors,
    required this.onRetry,
  });

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline, color: colors.error, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    state.error?.message ?? 'Chat is unavailable.',
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.widgetConfig,
    required this.colors,
    required this.onRetry,
    required this.onRemove,
    required this.onRefresh,
  });

  final WisperBotMessage message;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final visitor = message.role == WisperBotMessageRole.visitor;
    final status = _statusLabel(message.status);
    return Semantics(
      label:
          '${visitor ? 'Your' : 'Support'} message. ${message.body}${visitor ? '. $status' : ''}',
      child: _BubbleLayout(
        visitor: visitor,
        widgetConfig: widgetConfig,
        colors: colors,
        bubbleKey: ValueKey<String>(
          'wisperbot-message-bubble-${message.localId}',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MessageContent(message: message, colors: colors),
            if (visitor) ...<Widget>[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    _statusIcon(message.status),
                    size: 13,
                    color: colors.onVisitorBubble.withValues(alpha: 0.72),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                colors.onVisitorBubble.withValues(alpha: 0.72),
                          ),
                    ),
                  ),
                ],
              ),
            ],
            if (onRetry != null || onRefresh != null || onRemove != null)
              Wrap(
                spacing: 4,
                children: <Widget>[
                  if (onRetry != null)
                    TextButton(
                      style: _messageActionStyle(visitor, colors),
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  if (onRefresh != null)
                    TextButton(
                      style: _messageActionStyle(visitor, colors),
                      onPressed: onRefresh,
                      child: const Text('Refresh status'),
                    ),
                  if (onRemove != null)
                    TextButton(
                      style: _messageActionStyle(visitor, colors),
                      onPressed: onRemove,
                      child: const Text('Remove'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  ButtonStyle _messageActionStyle(
    bool visitor,
    WisperBotResolvedTheme colors,
  ) =>
      TextButton.styleFrom(
        foregroundColor:
            visitor ? colors.onVisitorBubble : colors.onAgentBubble,
      );

  static String _statusLabel(WisperBotMessageStatus status) => switch (status) {
        WisperBotMessageStatus.pending => 'Sending',
        WisperBotMessageStatus.sent => 'Sent',
        WisperBotMessageStatus.failed => 'Failed',
        WisperBotMessageStatus.unconfirmed => 'Delivery unconfirmed',
      };

  static IconData _statusIcon(WisperBotMessageStatus status) =>
      switch (status) {
        WisperBotMessageStatus.pending => Icons.schedule,
        WisperBotMessageStatus.sent => Icons.check,
        WisperBotMessageStatus.failed => Icons.error_outline,
        WisperBotMessageStatus.unconfirmed => Icons.help_outline,
      };
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message, required this.colors});

  final WisperBotMessage message;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) {
    final textColor = message.role == WisperBotMessageRole.visitor
        ? colors.onVisitorBubble
        : colors.onAgentBubble;
    final attachment = message.attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (message.type == WisperBotMessageType.image && attachment != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: WisperBotRemoteImage(
                url: attachment.url,
                fit: BoxFit.cover,
                semanticLabel: attachment.filename ?? 'Image attachment',
                errorBuilder: (_) => const SizedBox(
                  height: 96,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ),
        if (message.type == WisperBotMessageType.audio)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.audiotrack),
                SizedBox(width: 8),
                Flexible(child: Text('Audio message')),
              ],
            ),
          ),
        SelectableText(
          message.body,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: textColor, height: 1.4),
        ),
      ],
    );
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator({required this.typing, required this.colors});

  final WisperBotAgentTyping typing;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: 'Support is typing',
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: colors.agentBubble,
              borderRadius: BorderRadius.circular(colors.borderRadius),
            ),
            child: Text(
              typing.name?.trim().isNotEmpty == true
                  ? '${typing.name} is typing…'
                  : 'Support is typing…',
              style: TextStyle(color: colors.onAgentBubble),
            ),
          ),
        ),
      );
}

class _HandoffAction extends StatelessWidget {
  const _HandoffAction({
    required this.state,
    required this.colors,
    required this.onPressed,
  });

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final status = state.handoff.status;
    if (status == WisperBotHandoffStatus.unavailable) {
      return const SizedBox.shrink();
    }
    final isActionable = status == WisperBotHandoffStatus.eligible ||
        status == WisperBotHandoffStatus.failed;
    final prompt = switch (status) {
      WisperBotHandoffStatus.eligible => 'Prefer a person?',
      WisperBotHandoffStatus.requesting => 'Connecting to a human agent…',
      WisperBotHandoffStatus.connected => 'Connected to a human agent',
      WisperBotHandoffStatus.failed => 'Could not connect.',
      WisperBotHandoffStatus.unavailable => '',
    };
    final actionLabel =
        status == WisperBotHandoffStatus.failed ? 'Try again' : 'Human Agent';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (status == WisperBotHandoffStatus.requesting) ...<Widget>[
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              prompt,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
            ),
          ),
          if (isActionable) ...<Widget>[
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: status == WisperBotHandoffStatus.failed
                  ? 'Try human agent again'
                  : 'Request a human agent',
              child: OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primary,
                  side: BorderSide(color: colors.primary),
                  minimumSize: const Size(48, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(actionLabel),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BrandFooter extends StatelessWidget {
  const _BrandFooter({required this.companyName, required this.colors});

  final String? companyName;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) {
    final configured = companyName?.trim();
    final brand = configured?.isNotEmpty == true ? configured! : 'WisperBot';
    final baseStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceMuted.withValues(alpha: 0.7),
          fontSize: 11,
        );
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text.rich(
        TextSpan(
          text: 'Powered by ',
          children: <InlineSpan>[
            TextSpan(
              text: brand,
              style: baseStyle?.copyWith(
                color: colors.onSurfaceMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.center,
        style: baseStyle,
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.colors,
    required this.mediaAdapter,
    required this.imagesEnabled,
    required this.audioEnabled,
  });

  final WisperBotChatController controller;
  final WisperBotResolvedTheme colors;
  final WisperBotMediaAdapter? mediaAdapter;
  final bool imagesEnabled;
  final bool audioEnabled;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _mediaBusy = false;
  bool _isRecording = false;
  WisperBotUpload? _pendingImage;

  @override
  Widget build(BuildContext context) {
    final mediaAdapter = widget.mediaAdapter;
    final showImage = mediaAdapter != null && widget.imagesEnabled;
    final showAudio = mediaAdapter != null && widget.audioEnabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        border: Border(top: BorderSide(color: widget.colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 9, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_pendingImage != null)
              _ImagePreview(
                upload: _pendingImage!,
                colors: widget.colors,
                sending: _mediaBusy,
                onSend: _sendPendingImage,
                onDiscard: _discardPendingImage,
              ),
            if (_isRecording)
              _RecordingStatus(
                colors: widget.colors,
                onCancel: _mediaBusy ? null : _cancelRecording,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (showImage)
                  Semantics(
                    button: true,
                    label: 'Attach image',
                    child: IconButton(
                      tooltip: 'Attach image',
                      onPressed: _mediaBusy || _isRecording ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      color: widget.colors.onSurfaceMuted,
                    ),
                  ),
                if (showAudio)
                  Semantics(
                    button: true,
                    label: _isRecording
                        ? 'Stop and send voice message'
                        : 'Record voice message',
                    child: IconButton(
                      tooltip: _isRecording
                          ? 'Stop and send voice message'
                          : 'Record voice message',
                      onPressed: _mediaBusy || _pendingImage != null
                          ? null
                          : _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_none,
                      ),
                      color: _isRecording
                          ? widget.colors.error
                          : widget.colors.onSurfaceMuted,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message…',
                      hintStyle: TextStyle(color: widget.colors.onSurfaceMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                    ),
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: widget.colors.primary,
                      foregroundColor: widget.colors.onPrimary,
                      disabledBackgroundColor: widget.colors.surfaceMuted,
                      disabledForegroundColor: widget.colors.onSurfaceMuted,
                    ),
                    tooltip: 'Send message',
                    onPressed:
                        _hasText && !_mediaBusy && !_isRecording ? _send : null,
                    icon: const Icon(Icons.send_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    unawaited(widget.controller.setTyping(hasText));
  }

  Future<void> _pickImage() async {
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
    setState(() => _mediaBusy = true);
    try {
      final upload = await adapter.pickImage();
      if (!mounted) return;
      if (upload != null) setState(() => _pendingImage = upload);
    } on Object catch (error) {
      if (mounted) _showMediaError(error, 'The image could not be selected.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _sendPendingImage() async {
    final upload = _pendingImage;
    if (upload == null) return;
    setState(() => _mediaBusy = true);
    try {
      final caption = _textController.text.trim();
      await widget.controller.sendImage(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      _textController.clear();
      setState(() {
        _hasText = false;
        _pendingImage = null;
      });
    } on Object catch (error) {
      if (mounted) _showMediaError(error, 'The image could not be sent.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  void _discardPendingImage() => setState(() => _pendingImage = null);

  Future<void> _toggleRecording() async {
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
    setState(() => _mediaBusy = true);
    try {
      if (!_isRecording) {
        await adapter.startAudioRecording();
        if (mounted) setState(() => _isRecording = true);
        return;
      }

      final upload = await adapter.stopAudioRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (upload == null) return;
      final caption = _textController.text.trim();
      await widget.controller.sendAudio(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      _textController.clear();
      setState(() => _hasText = false);
    } on Object catch (error) {
      if (_isRecording) {
        try {
          await adapter.cancelAudioRecording();
        } on Object {
          // Preserve the original error for the visitor.
        }
      }
      if (mounted) {
        setState(() => _isRecording = false);
        _showMediaError(error, 'The voice message could not be recorded.');
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _cancelRecording() async {
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
    setState(() => _mediaBusy = true);
    try {
      await adapter.cancelAudioRecording();
    } on Object catch (error) {
      if (mounted) _showMediaError(error, 'Recording could not be cancelled.');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _mediaBusy = false;
        });
      }
    }
  }

  void _showMediaError(Object error, String fallback) {
    final message = error is WisperBotException ? error.message : fallback;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _send() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _hasText = false);
    unawaited(_sendMessage(text));
  }

  Future<void> _sendMessage(String text) async {
    try {
      await widget.controller.sendText(text);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is WisperBotException
          ? error.message
          : 'The message could not be sent.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    final adapter = widget.mediaAdapter;
    if (_isRecording && adapter != null) {
      unawaited(adapter.cancelAudioRecording().catchError((_) {}));
    }
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.upload,
    required this.colors,
    required this.sending,
    required this.onSend,
    required this.onDiscard,
  });

  final WisperBotUpload upload;
  final WisperBotResolvedTheme colors;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('wisperbot-image-preview'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                upload.bytes,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox.square(
                  dimension: 52,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                upload.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: sending ? null : onSend,
              child: const Text('Send'),
            ),
            IconButton(
              tooltip: 'Discard image',
              onPressed: sending ? null : onDiscard,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.colors, required this.onCancel});

  final WisperBotResolvedTheme colors;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: 'Recording voice message',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: <Widget>[
              Icon(Icons.fiber_manual_record, size: 14, color: colors.error),
              const SizedBox(width: 6),
              const Expanded(child: Text('Recording… tap stop to send')),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ),
      );
}
