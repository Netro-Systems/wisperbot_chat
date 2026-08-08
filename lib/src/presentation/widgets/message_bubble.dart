part of '../view/chat_view.dart';

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
