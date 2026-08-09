part of '../view/chat_view.dart';

/// Internal in-memory image preview owned by the active composer state.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.upload,
    required this.colors,
    required this.sending,
    required this.onDiscard,
  });

  final WisperBotUpload upload;
  final WisperBotResolvedTheme colors;
  final bool sending;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('wisperbot-image-preview'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                upload.bytes,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => SizedBox.square(
                  dimension: 52,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                upload.filename,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Discard image',
              onPressed: sending ? null : onDiscard,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}
