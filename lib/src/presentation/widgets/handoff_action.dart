part of '../view/chat_view.dart';

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
    final agentName = state.handoff.agentName?.trim();
    final prompt = switch (status) {
      WisperBotHandoffStatus.eligible => 'Need a person?',
      WisperBotHandoffStatus.requesting => 'Requesting human support…',
      WisperBotHandoffStatus.waiting => 'Waiting for an agent to join…',
      WisperBotHandoffStatus.connected => agentName?.isNotEmpty == true
          ? '$agentName joined this chat'
          : 'An agent joined this chat',
      WisperBotHandoffStatus.failed => 'Could not connect.',
      WisperBotHandoffStatus.unavailable => '',
    };
    final actionLabel = status == WisperBotHandoffStatus.failed
        ? 'Try again'
        : 'Talk to an agent';
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          colors.primary.withValues(alpha: 0.08),
          colors.surface,
        ),
        border: Border(
            bottom: BorderSide(color: colors.primary.withValues(alpha: 0.16))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          ] else ...<Widget>[
            Icon(Icons.headset_mic_outlined,
                size: 16, color: colors.onSurfaceMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
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
              child: TextButton(
                onPressed: onPressed,
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
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
