part of '../view/chat_view.dart';

/// In-memory image previews owned by the active composer state.
class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.uploads,
    required this.colors,
    required this.sending,
    required this.onDiscard,
  });

  final List<WisperBotUpload> uploads;
  final WisperBotResolvedTheme colors;
  final bool sending;
  final ValueChanged<WisperBotUpload> onDiscard;

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
        child:
            uploads.length == 1 ? _singleImage(context) : _imageStrip(context),
      );

  Widget _singleImage(BuildContext context) => Row(
        children: <Widget>[
          _thumbnail(context, uploads.single, size: 52),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              uploads.single.filename,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Discard image',
            onPressed: sending ? null : () => onDiscard(uploads.single),
            icon: _ComposerAssetIcon(
              assetName: 'assets/icons/remove.png',
              color: sending ? colors.onSurfaceMuted : colors.onSurface,
              size: 26,
            ),
          ),
        ],
      );

  Widget _imageStrip(BuildContext context) => SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (var index = 0; index < uploads.length; index++)
                Padding(
                  key: ObjectKey(uploads[index]),
                  padding:
                      EdgeInsetsDirectional.only(start: index == 0 ? 0 : 8),
                  child: Stack(
                    children: <Widget>[
                      _thumbnail(context, uploads[index], size: 64),
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: IconButton(
                          tooltip: 'Discard image ${index + 1}',
                          onPressed:
                              sending ? null : () => onDiscard(uploads[index]),
                          icon: const Icon(Icons.cancel, size: 20),
                          style: IconButton.styleFrom(
                            foregroundColor: colors.onSurface,
                            disabledForegroundColor: colors.onSurfaceMuted,
                            backgroundColor: colors.surface,
                            minimumSize: const Size.square(36),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _thumbnail(
    BuildContext context,
    WisperBotUpload upload, {
    required double size,
  }) =>
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          upload.bytes,
          width: size,
          height: size,
          cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
          fit: BoxFit.cover,
          semanticLabel: upload.filename,
          errorBuilder: (_, __, ___) => SizedBox.square(
            dimension: size,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: colors.onSurfaceMuted,
            ),
          ),
        ),
      );
}
