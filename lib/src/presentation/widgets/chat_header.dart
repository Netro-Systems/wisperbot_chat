part of '../view/chat_view.dart';

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
