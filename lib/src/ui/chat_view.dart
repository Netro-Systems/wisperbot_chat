import 'dart:async';

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import '../domain/errors.dart';
import '../domain/models.dart';
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
  });

  final WisperBotConfig config;
  final WisperBotChatController? controller;
  final bool showHeader;
  final WisperBotChatStateBuilder? emptyBuilder;
  final WisperBotChatStateBuilder? errorBuilder;
  final WisperBotMessageBuilder? messageBuilder;
  final WisperBotComposerBuilder? composerBuilder;

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
    final colors = WisperBotResolvedTheme.resolve(
      hostTheme: Theme.of(context),
      server: _state.widget,
      override: widget.config.theme,
    );
    return ColoredBox(
      color: colors.background,
      child: Column(
        children: <Widget>[
          if (widget.showHeader) _ChatHeader(state: _state, colors: colors),
          if (_state.phase == WisperBotChatPhase.reconnecting)
            _ConnectionBanner(colors: colors),
          if (_state.supportAvailability ==
              WisperBotSupportAvailability.unavailable)
            _AvailabilityBanner(state: _state, colors: colors),
          Expanded(child: _buildBody(colors)),
          if (_canCompose(_state)) _buildComposer(colors),
        ],
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
          return widget.emptyBuilder?.call(context, _state) ??
              _EmptyState(state: _state, colors: colors);
        }
        return _timeline(colors);
      case WisperBotChatPhase.disposed:
        return const SizedBox.shrink();
    }
  }

  Widget _timeline(WisperBotResolvedTheme colors) => RefreshIndicator(
        color: colors.primary,
        onRefresh: _controller.refresh,
        child: Stack(
          children: <Widget>[
            ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount:
                  _state.messages.length + (_state.agentTyping == null ? 0 : 1),
              itemBuilder: (context, index) {
                if (index == _state.messages.length) {
                  return _TypingIndicator(
                    typing: _state.agentTyping!,
                    colors: colors,
                  );
                }
                final message = _state.messages[index];
                return Padding(
                  padding: EdgeInsets.only(bottom: colors.messageSpacing),
                  child: widget.messageBuilder?.call(context, message) ??
                      _MessageBubble(
                        message: message,
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
                        onRemove: message.status ==
                                    WisperBotMessageStatus.failed ||
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

  Widget _buildComposer(WisperBotResolvedTheme colors) {
    final custom = widget.composerBuilder;
    if (custom != null) return custom(context, _controller, _state);
    return Column(
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
      ],
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
  const _ChatHeader({required this.state, required this.colors});

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) {
    final widgetConfig = state.widget;
    final title = widgetConfig?.title.trim().isNotEmpty == true
        ? widgetConfig!.title
        : 'Chat with us';
    final subtitle = _subtitle(state);
    return Material(
      color: colors.surface,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              CircleAvatar(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                child: const Icon(Icons.chat_bubble_outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.state, required this.colors});

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.waving_hand_outlined,
                    color: colors.primary, size: 36),
                const SizedBox(height: 16),
                Text(
                  state.widget?.welcomeMessage.trim().isNotEmpty == true
                      ? state.widget!.welcomeMessage
                      : 'Hi! How can we help?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      );
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
    required this.colors,
    required this.onRetry,
    required this.onRemove,
    required this.onRefresh,
  });

  final WisperBotMessage message;
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
      child: Align(
        alignment: visitor
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: FractionallySizedBox(
            widthFactor: 0.76,
            alignment: visitor
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: visitor ? colors.visitorBubble : colors.agentBubble,
                borderRadius: BorderRadius.circular(colors.borderRadius),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (message.senderName?.trim().isNotEmpty == true &&
                        !visitor)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          message.senderName!,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: colors.onAgentBubble,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                    _MessageContent(message: message, colors: colors),
                    if (visitor) ...<Widget>[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            _statusIcon(message.status),
                            size: 13,
                            color:
                                colors.onVisitorBubble.withValues(alpha: 0.72),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              status,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colors.onVisitorBubble
                                        .withValues(alpha: 0.72),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (onRetry != null ||
                        onRefresh != null ||
                        onRemove != null)
                      Wrap(
                        spacing: 4,
                        children: <Widget>[
                          if (onRetry != null)
                            TextButton(
                                onPressed: onRetry, child: const Text('Retry')),
                          if (onRefresh != null)
                            TextButton(
                              onPressed: onRefresh,
                              child: const Text('Refresh status'),
                            ),
                          if (onRemove != null)
                            TextButton(
                              onPressed: onRemove,
                              child: const Text('Remove'),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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
              child: Image.network(
                attachment.url.toString(),
                fit: BoxFit.cover,
                semanticLabel: attachment.filename ?? 'Image attachment',
                errorBuilder: (_, __, ___) => const SizedBox(
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
              ?.copyWith(color: textColor),
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
  Widget build(BuildContext context) => Material(
        color: widget.colors.surface,
        elevation: 4,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
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
                      hintText: 'Write a message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
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
                const SizedBox(width: 4),
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _hasText ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
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
