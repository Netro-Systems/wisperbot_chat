part of '../view/chat_view.dart';

/// Internal leading welcome content that never enters message state.
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
