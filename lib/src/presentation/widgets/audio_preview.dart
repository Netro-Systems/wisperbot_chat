part of '../view/chat_view.dart';

/// Internal audio confirmation shown before an upload is dispatched.
class _AudioPreview extends StatelessWidget {
  const _AudioPreview({
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
        key: const ValueKey<String>('wisperbot-audio-preview'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.graphic_eq_rounded, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                upload.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: sending ? null : onSend,
              child: const Text('Send'),
            ),
            IconButton(
              tooltip: 'Discard voice message',
              onPressed: sending ? null : onDiscard,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}
