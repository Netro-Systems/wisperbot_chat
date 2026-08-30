part of '../view/chat_view.dart';

const Color _deliverySeen = Color(0xFF53BDEB);

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.controller,
    required this.widgetConfig,
    required this.colors,
    required this.onRetry,
    required this.onRemove,
    required this.onRefresh,
  });

  final WisperBotMessage message;
  final WisperBotChatController controller;
  final WisperBotWidgetConfig? widgetConfig;
  final WisperBotResolvedTheme colors;
  final VoidCallback? onRetry;
  final VoidCallback? onRemove;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final visitor = message.role == WisperBotMessageRole.visitor;
    final deliveryLabel = visitor ? ', ${_deliveryLabel(message.status)}' : '';
    return Semantics(
      label: '${visitor ? 'Your' : 'Support'} message. ${message.body}$deliveryLabel',
      child: _BubbleLayout(
        visitor: visitor,
        widgetConfig: widgetConfig,
        colors: colors,
        isImage: message.type == WisperBotMessageType.image,
        bubbleKey: ValueKey<String>(
          'wisperbot-message-bubble-${message.localId}',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _MessageContent(
              message: message,
              colors: colors,
              controller: controller,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  _time(message.createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: visitor
                            ? colors.onVisitorBubble.withValues(alpha: 0.72)
                            : colors.onAgentBubble.withValues(alpha: 0.72),
                      ),
                ),
                if (visitor) ...<Widget>[
                  const SizedBox(width: 4),
                  Icon(
                    _deliveryIcon(message.status),
                    size: 14,
                    color: _deliveryColor(colors, message.status),
                  ),
                ],
              ],
            ),
            if (onRetry != null || onRefresh != null || onRemove != null) ...<Widget>[
              const SizedBox(height: 4),
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
        foregroundColor: visitor ? colors.onVisitorBubble : colors.onAgentBubble,
      );

  static String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${value.hour >= 12 ? 'PM' : 'AM'}';
  }

  static String _deliveryLabel(WisperBotMessageStatus status) => switch (status) {
        WisperBotMessageStatus.pending => 'sending',
        WisperBotMessageStatus.sent => 'sent',
        WisperBotMessageStatus.delivered => 'delivered',
        WisperBotMessageStatus.read => 'read',
        WisperBotMessageStatus.failed => 'failed',
        WisperBotMessageStatus.unconfirmed => 'delivery unconfirmed',
      };

  static IconData _deliveryIcon(WisperBotMessageStatus status) => switch (status) {
        WisperBotMessageStatus.pending => Icons.schedule,
        WisperBotMessageStatus.sent => Icons.check,
        WisperBotMessageStatus.delivered || WisperBotMessageStatus.read => Icons.done_all,
        WisperBotMessageStatus.failed => Icons.error_outline,
        WisperBotMessageStatus.unconfirmed => Icons.help_outline,
      };

  static Color _deliveryColor(
    WisperBotResolvedTheme colors,
    WisperBotMessageStatus status,
  ) =>
      switch (status) {
        WisperBotMessageStatus.pending => colors.onVisitorBubble.withValues(alpha: 0.60),
        WisperBotMessageStatus.sent ||
        WisperBotMessageStatus.delivered ||
        WisperBotMessageStatus.unconfirmed =>
          colors.onVisitorBubble.withValues(alpha: 0.72),
        WisperBotMessageStatus.read => _deliverySeen,
        WisperBotMessageStatus.failed => colors.error,
      };
}
