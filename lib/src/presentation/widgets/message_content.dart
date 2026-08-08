part of '../view/chat_view.dart';

/// Internal safe renderer for one message's text and supported attachment.
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
