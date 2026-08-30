part of '../view/chat_view.dart';

/// Internal in-memory document/file preview owned by the active composer state.
class _FilePreview extends StatelessWidget {
  const _FilePreview({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final ext = _documentExtension(upload.filename);
    final (icon, badgeColor) = _documentIconAndColor(ext);

    return Container(
      key: const ValueKey<String>('wisperbot-file-preview'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        border: Border.all(color: colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: isDark ? 0.25 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                icon,
                color: badgeColor,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  upload.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFileSize(upload.bytes.length),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Discard file',
            onPressed: sending ? null : onDiscard,
            icon: const Icon(Icons.close, size: 20),
          ),
        ],
      ),
    );
  }
}

String _documentExtension(String fileName) {
  if (!fileName.contains('.')) return 'DOC';
  final ext = fileName.split('.').last.trim().toUpperCase();
  return ext.isEmpty ? 'DOC' : ext;
}

(IconData, Color) _documentIconAndColor(String ext) {
  return switch (ext.toUpperCase()) {
    'PDF' => (Icons.picture_as_pdf_rounded, const Color(0xFFE53935)),
    'DOC' || 'DOCX' => (Icons.description_rounded, const Color(0xFF1E88E5)),
    'XLS' || 'XLSX' || 'CSV' => (Icons.table_chart_rounded, const Color(0xFF43A047)),
    'PPT' || 'PPTX' => (Icons.slideshow_rounded, const Color(0xFFFB8C00)),
    'TXT' || 'JSON' || 'XML' || 'MD' || 'LOG' || 'HTML' => (
        Icons.article_rounded,
        const Color(0xFF5E35B1),
      ),
    'ZIP' || 'RAR' || '7Z' || 'TAR' || 'GZ' => (
        Icons.folder_zip_rounded,
        const Color(0xFFF4511E),
      ),
    _ => (Icons.insert_drive_file_rounded, const Color(0xFF3949AB)),
  };
}

String _formatFileSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
