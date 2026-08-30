part of '../view/chat_view.dart';

/// Available options in the attachment picker bottom sheet.
enum AttachmentOption {
  /// File or document attachment.
  document,

  /// Take a photo using the device camera.
  camera,

  /// Select a photo or media from the device gallery.
  gallery,

  /// Record or send an audio voice message.
  audio,
}

/// Modal bottom sheet for picking attachment types (Camera, Gallery, Audio, Document).
final class AttachmentPickerSheet extends StatelessWidget {
  /// Creates an attachment picker sheet.
  const AttachmentPickerSheet({
    this.showDocument = true,
    this.showCamera = true,
    this.showGallery = true,
    this.showAudio = true,
    super.key,
  });

  /// Whether the document option is visible.
  final bool showDocument;

  /// Whether the camera option is visible.
  final bool showCamera;

  /// Whether the gallery option is visible.
  final bool showGallery;

  /// Whether the audio recording option is visible.
  final bool showAudio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    final items = <_AttachmentItemData>[
      if (showDocument)
        const _AttachmentItemData(
          option: AttachmentOption.document,
          label: 'Document',
          icon: Icons.insert_drive_file_rounded,
          gradientColors: <Color>[Color(0xFF7F66FF), Color(0xFF5F66CD)],
          tooltip: 'Send document or file',
        ),
      if (showCamera)
        const _AttachmentItemData(
          option: AttachmentOption.camera,
          label: 'Camera',
          icon: Icons.camera_alt_rounded,
          gradientColors: <Color>[Color(0xFFEC407A), Color(0xFFD3396D)],
          tooltip: 'Take photo with camera',
        ),
      if (showGallery)
        const _AttachmentItemData(
          option: AttachmentOption.gallery,
          label: 'Gallery',
          icon: Icons.photo_library_rounded,
          gradientColors: <Color>[Color(0xFFAC44CF), Color(0xFF8E24AA)],
          tooltip: 'Choose photo from gallery',
        ),
      if (showAudio)
        const _AttachmentItemData(
          option: AttachmentOption.audio,
          label: 'Audio',
          icon: Icons.headphones_rounded,
          gradientColors: <Color>[Color(0xFFFA6A26), Color(0xFFF57C00)],
          tooltip: 'Record voice message',
        ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2024) : colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 18,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.95,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final item = items[index];
                  return _AttachmentGridItem(
                    data: item,
                    onTap: () => Navigator.of(context).pop(item.option),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _AttachmentItemData {
  const _AttachmentItemData({
    required this.option,
    required this.label,
    required this.icon,
    required this.gradientColors,
    required this.tooltip,
  });

  final AttachmentOption option;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final String tooltip;
}

final class _AttachmentGridItem extends StatelessWidget {
  const _AttachmentGridItem({required this.data, required this.onTap});

  final _AttachmentItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: data.tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: data.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: data.gradientColors.last.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(data.icon, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? const Color(0xFFE1E2E5)
                      : const Color(0xFF2C2D30),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
