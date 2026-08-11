part of '../view/chat_view.dart';

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
