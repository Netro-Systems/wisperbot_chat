import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import '../domain/errors.dart';
import '../domain/models.dart';
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
        child: Column(
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

  Widget _buildBody(WisperBotResolvedTheme colors) {
    switch (_state.phase) {
      case WisperBotChatPhase.idle:
      case WisperBotChatPhase.initializing:
      case WisperBotChatPhase.expired:
        return Semantics(
          label: 'Connecting to chat',
          liveRegion: true,
          child: Center(
            child: CircularProgressIndicator(color: colors.primary),
          ),
        );
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
            _Composer(controller: _controller, colors: colors),
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
                foregroundColor: colors.onPrimary,
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
                      foregroundColor: colors.onPrimary,
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
    required this.foregroundColor,
    this.borderColor,
  });

  final Uri? avatarUrl;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final assetSize = size * 0.56;
    final fallback = Center(
      child: Icon(
        Icons.support_agent_rounded,
        size: assetSize,
        color: foregroundColor,
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
    final label = switch (status) {
      WisperBotHandoffStatus.eligible => 'Talk to a person',
      WisperBotHandoffStatus.requesting => 'Requesting support…',
      WisperBotHandoffStatus.connected => 'Connected to support',
      WisperBotHandoffStatus.failed => 'Try human support again',
      WisperBotHandoffStatus.unavailable => '',
    };
    return Material(
      color: colors.surface,
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: status == WisperBotHandoffStatus.eligible ||
                  status == WisperBotHandoffStatus.failed
              ? onPressed
              : null,
          icon: status == WisperBotHandoffStatus.requesting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.support_agent),
          label: Text(label),
        ),
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
  const _Composer({required this.controller, required this.colors});

  final WisperBotChatController controller;
  final WisperBotResolvedTheme colors;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: widget.colors.surface,
          border: Border(top: BorderSide(color: widget.colors.outline)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 9, 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
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
                  onChanged: (value) {
                    final hasText = value.trim().isNotEmpty;
                    if (hasText != _hasText) {
                      setState(() => _hasText = hasText);
                    }
                    unawaited(widget.controller.setTyping(hasText));
                  },
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
                  onPressed: _hasText ? _send : null,
                  icon: const Icon(Icons.send_rounded, size: 21),
                ),
              ),
            ],
          ),
        ),
      );

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
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
