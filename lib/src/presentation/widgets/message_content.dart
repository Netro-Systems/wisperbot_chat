part of '../view/chat_view.dart';

/// Internal safe renderer for one message's text and supported attachment.
class _MessageContent extends StatelessWidget {
  const _MessageContent({
    required this.message,
    required this.colors,
    required this.controller,
  });

  final WisperBotMessage message;
  final WisperBotResolvedTheme colors;
  final WisperBotChatController controller;

  @override
  Widget build(BuildContext context) {
    final textColor = message.role == WisperBotMessageRole.visitor
        ? colors.onVisitorBubble
        : colors.onAgentBubble;
    final attachment = message.attachment;
    final localUpload = message.localUpload;
    final hasMedia = attachment != null || localUpload != null;

    final isImage = message.type == WisperBotMessageType.image ||
        (hasMedia &&
            _isImageAttachment(
              filename: attachment?.filename ?? localUpload?.filename,
              mimeType: attachment?.mimeType ?? localUpload?.mimeType,
              url: attachment?.url,
            ));

    final isAudio = message.type == WisperBotMessageType.audio ||
        (hasMedia &&
            _isAudioAttachment(
              filename: attachment?.filename ?? localUpload?.filename,
              mimeType: attachment?.mimeType ?? localUpload?.mimeType,
              url: attachment?.url,
            ));

    final isFile =
        (message.type == WisperBotMessageType.file || (!isImage && !isAudio)) && hasMedia;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (isImage && hasMedia)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ImageAttachmentPreview(
              message: message,
              attachment: attachment,
              localUpload: localUpload,
            ),
          ),
        if (isAudio && hasMedia)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AudioAttachmentPlayer(
              attachment: attachment,
              localUpload: localUpload,
              colors: colors,
              visitor: message.role == WisperBotMessageRole.visitor,
              loadAttachmentBytes: controller.loadAttachmentBytes,
            ),
          ),
        if (isFile)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _FileAttachmentBubble(
              message: message,
              colors: colors,
            ),
          ),
        if (_visibleMessageBody(message).isNotEmpty)
          SelectableText(
            _visibleMessageBody(message),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor, height: 1.4),
          ),
      ],
    );
  }
}

bool _isImageAttachment({String? filename, String? mimeType, Uri? url}) {
  if (mimeType != null && mimeType.toLowerCase().startsWith('image/')) {
    return true;
  }
  final target = (filename ?? url?.path ?? '').toLowerCase();
  return RegExp(r'\.(jpg|jpeg|png|webp|gif|svg|heic|heif)$').hasMatch(target);
}

bool _isAudioAttachment({String? filename, String? mimeType, Uri? url}) {
  if (mimeType != null && mimeType.toLowerCase().startsWith('audio/')) {
    return true;
  }
  final target = (filename ?? url?.path ?? '').toLowerCase();
  return RegExp(r'\.(mp3|wav|m4a|aac|ogg|oga|webm|opus|amr)$').hasMatch(target);
}

class _ImageAttachmentPreview extends StatelessWidget {
  const _ImageAttachmentPreview({
    required this.message,
    this.attachment,
    this.localUpload,
  });

  final WisperBotMessage message;
  final WisperBotAttachment? attachment;
  final WisperBotUpload? localUpload;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filename = localUpload?.filename ?? attachment?.filename ?? 'Image';
    final isPending = message.status == WisperBotMessageStatus.pending;
    final isFailed = message.status == WisperBotMessageStatus.failed ||
        message.status == WisperBotMessageStatus.unconfirmed;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _ImageViewerScreen(
            filename: filename,
            upload: localUpload,
            attachment: attachment,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: double.infinity,
          height: 260,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(
                color: Colors.black.withValues(alpha: 0.06),
                child: localUpload != null
                    ? Image.memory(
                        localUpload!.bytes,
                        key: const ValueKey<String>(
                          'wisperbot-local-image-preview',
                        ),
                        fit: BoxFit.cover,
                        semanticLabel: localUpload!.filename,
                        errorBuilder: (context, error, stackTrace) => _imageError(theme, filename),
                      )
                    : attachment != null
                        ? Image.network(
                            attachment!.url.toString(),
                            key: const ValueKey<String>(
                              'wisperbot-remote-image-preview',
                            ),
                            fit: BoxFit.cover,
                            semanticLabel: attachment!.filename ?? 'Image attachment',
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: 160,
                                width: double.infinity,
                                color: Colors.black.withValues(alpha: 0.08),
                                alignment: Alignment.center,
                                child: const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                _imageError(theme, filename),
                          )
                        : _imageError(theme, filename),
              ),
              if (isPending)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!isPending && !isFailed && (attachment != null || localUpload != null))
                Positioned(
                  top: 6,
                  right: 6,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _downloadAttachmentToDevice(
                        context,
                        filename: filename,
                        attachment: attachment,
                        upload: localUpload,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              if (isFailed)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: DecoratedBox(
                    key: ValueKey<String>('wisperbot-local-image-error'),
                    decoration: BoxDecoration(
                      color: Color(0xCC000000),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageError(ThemeData theme, String filename) {
    return Container(
      width: double.infinity,
      height: 160,
      padding: const EdgeInsets.all(10),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.broken_image_outlined),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              filename,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  const _ImageViewerScreen({
    required this.filename,
    this.upload,
    this.attachment,
  });

  final String filename;
  final WisperBotUpload? upload;
  final WisperBotAttachment? attachment;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Download image',
            onPressed: () => _downloadAttachmentToDevice(
              context,
              filename: filename,
              attachment: attachment,
              upload: upload,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return InteractiveViewer(
            constrained: false,
            minScale: 1,
            maxScale: 5,
            child: SizedBox(
              width: constraints.maxWidth,
              child: upload != null
                  ? Image.memory(
                      upload!.bytes,
                      width: constraints.maxWidth,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (context, error, stackTrace) => _viewerError(constraints),
                    )
                  : attachment != null
                      ? Image.network(
                          attachment!.url.toString(),
                          width: constraints.maxWidth,
                          fit: BoxFit.fitWidth,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              width: constraints.maxWidth,
                              height: constraints.maxHeight,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => _viewerError(constraints),
                        )
                      : _viewerError(constraints),
            ),
          );
        },
      ),
    );
  }

  Widget _viewerError(BoxConstraints constraints) {
    return SizedBox(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      child: const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.white70,
          size: 48,
        ),
      ),
    );
  }
}

class _AudioAttachmentPlayer extends StatefulWidget {
  const _AudioAttachmentPlayer({
    required this.attachment,
    required this.localUpload,
    required this.colors,
    required this.visitor,
    required this.loadAttachmentBytes,
  });

  final WisperBotAttachment? attachment;
  final WisperBotUpload? localUpload;
  final WisperBotResolvedTheme colors;
  final bool visitor;
  final Future<Uint8List> Function(WisperBotAttachment attachment) loadAttachmentBytes;

  @override
  State<_AudioAttachmentPlayer> createState() => _AudioAttachmentPlayerState();
}

class _AudioAttachmentPlayerState extends State<_AudioAttachmentPlayer> {
  static final Map<Uri, Future<Uint8List>> _downloadCache = <Uri, Future<Uint8List>>{};

  late final AudioPlayer _player;
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _AudioPlaybackCoordinator.clear(_player);
        _player.pause();
        _player.seek(Duration.zero);
      }
    });
    unawaited(_loadAudio());
  }

  @override
  void didUpdateWidget(covariant _AudioAttachmentPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment?.url != widget.attachment?.url ||
        !identical(oldWidget.localUpload, widget.localUpload)) {
      unawaited(_loadAudio());
    }
  }

  Future<void> _loadAudio() async {
    setState(() {
      _ready = false;
      _failed = false;
    });

    try {
      final source = await _audioSource();
      await _setAudioSourceWithFallbacks(source.bytes, source.contentTypes);
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<_AudioSourceBytes> _audioSource() async {
    final localUpload = widget.localUpload;
    if (localUpload != null) {
      return _AudioSourceBytes(
        bytes: localUpload.bytes,
        contentTypes: _candidateLocalAudioContentTypes(localUpload),
      );
    }
    final attachment = widget.attachment;
    if (attachment == null) {
      throw StateError('Audio message has no local or remote source.');
    }
    return _AudioSourceBytes(
      bytes: await _cachedAttachmentBytes(attachment),
      contentTypes: _candidateAudioContentTypes(attachment),
    );
  }

  Future<Uint8List> _cachedAttachmentBytes(WisperBotAttachment attachment) async {
    final future = _downloadCache.putIfAbsent(
      attachment.url,
      () => widget.loadAttachmentBytes(attachment),
    );
    try {
      return await future;
    } on Object {
      _downloadCache.remove(attachment.url);
      rethrow;
    }
  }

  Future<void> _setAudioSourceWithFallbacks(
    Uint8List bytes,
    List<String> contentTypes,
  ) async {
    Object? lastError;
    for (final contentType in contentTypes) {
      try {
        await _player.setAudioSource(
          AudioSource.uri(
            Uri.dataFromBytes(bytes, mimeType: contentType),
          ),
        );
        return;
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? StateError('Audio source could not be loaded.');
  }

  Future<void> _togglePlayback() async {
    if (!_ready || _failed) return;
    if (_player.playing) {
      await _AudioPlaybackCoordinator.pause(_player);
      return;
    }
    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _AudioPlaybackCoordinator.play(_player);
  }

  @override
  void dispose() {
    _AudioPlaybackCoordinator.clear(_player);
    _playerStateSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = widget.visitor ? widget.colors.onVisitorBubble : widget.colors.onAgentBubble;
    final muted = foreground.withValues(alpha: 0.72);
    final trackColor = foreground.withValues(alpha: 0.18);
    final accent = widget.visitor ? foreground : widget.colors.primary;
    final surface = foreground.withValues(alpha: widget.visitor ? 0.13 : 0.06);

    if (_failed) {
      return Container(
        key: _localPreviewKey,
        width: 226,
        constraints: const BoxConstraints(maxWidth: 320),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 18, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Audio unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(color: muted),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: _localPreviewKey,
      width: 226,
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.fromLTRB(8, 7, 10, 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: StreamBuilder<PlayerState>(
        stream: _player.playerStateStream,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final playing = state?.playing ?? false;
          final loading = !_ready ||
              state?.processingState == ProcessingState.loading ||
              state?.processingState == ProcessingState.buffering;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 40,
                width: 40,
                child: IconButton.filled(
                  tooltip: playing ? 'Pause voice message' : 'Play voice message',
                  onPressed: loading ? null : _togglePlayback,
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    backgroundColor: accent.withValues(alpha: 0.16),
                    foregroundColor: accent,
                    disabledBackgroundColor: trackColor,
                    disabledForegroundColor: muted,
                  ),
                  icon: loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: _player.positionStream,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final duration = _player.duration ?? Duration.zero;

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _AudioProgressBar(
                          position: position,
                          duration: duration,
                          activeColor: accent,
                          inactiveColor: trackColor,
                          onSeek: loading || duration == Duration.zero ? null : _player.seek,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              _duration(position),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                              ),
                            ),
                            Text(
                              duration == Duration.zero ? '--:--' : _duration(duration),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Key? get _localPreviewKey => widget.localUpload != null && widget.attachment == null
      ? const ValueKey<String>('wisperbot-local-audio-preview')
      : null;
}

class _AudioSourceBytes {
  const _AudioSourceBytes({required this.bytes, required this.contentTypes});

  final Uint8List bytes;
  final List<String> contentTypes;
}

List<String> _candidateAudioContentTypes(WisperBotAttachment attachment) {
  final values = <String>[
    if (_validAudioMimeType(attachment.mimeType)) attachment.mimeType!.trim(),
    if (_validAudioMimeType(_inferAudioMimeType(attachment.filename)))
      _inferAudioMimeType(attachment.filename)!,
    if (_validAudioMimeType(_inferAudioMimeType(attachment.url.path)))
      _inferAudioMimeType(attachment.url.path)!,
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/amr',
  ];
  return <String>{
    for (final value in values) value.toLowerCase(),
  }.toList(growable: false);
}

List<String> _candidateLocalAudioContentTypes(WisperBotUpload upload) {
  final values = <String>[
    if (_validAudioMimeType(upload.mimeType)) upload.mimeType.trim(),
    if (_validAudioMimeType(_inferAudioMimeType(upload.filename)))
      _inferAudioMimeType(upload.filename)!,
    'audio/mpeg',
    'audio/mp4',
    'audio/aac',
    'audio/wav',
    'audio/ogg',
    'audio/webm',
    'audio/amr',
  ];
  return <String>{
    for (final value in values) value.toLowerCase(),
  }.toList(growable: false);
}

bool _validAudioMimeType(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized != null && normalized.isNotEmpty && normalized.startsWith('audio/');
}

String? _inferAudioMimeType(String? filenameOrPath) {
  final ext = (filenameOrPath ?? '').split('?').first.split('.').last.toLowerCase();
  return switch (ext) {
    'mp3' => 'audio/mpeg',
    'm4a' => 'audio/mp4',
    'mp4' => 'audio/mp4',
    'aac' => 'audio/aac',
    'amr' => 'audio/amr',
    'ogg' || 'oga' || 'opus' => 'audio/ogg',
    'wav' => 'audio/wav',
    'webm' => 'audio/webm',
    _ => null,
  };
}

class _AudioProgressBar extends StatelessWidget {
  const _AudioProgressBar({
    required this.position,
    required this.duration,
    required this.activeColor,
    required this.inactiveColor,
    required this.onSeek,
  });

  final Duration position;
  final Duration duration;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<Duration>? onSeek;

  @override
  Widget build(BuildContext context) {
    final totalMs = duration.inMilliseconds;
    final currentMs = position.inMilliseconds.clamp(
      0,
      totalMs <= 0 ? 0 : totalMs,
    );
    final progress = totalMs <= 0 ? 0.0 : currentMs / totalMs;

    return LayoutBuilder(
      builder: (context, constraints) {
        void seek(Offset globalPosition) {
          final callback = onSeek;
          if (callback == null || totalMs <= 0) return;
          final box = context.findRenderObject() as RenderBox?;
          if (box == null) return;
          final local = box.globalToLocal(globalPosition);
          final ratio = (local.dx / constraints.maxWidth).clamp(0.0, 1.0);
          callback(Duration(milliseconds: (totalMs * ratio).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onSeek == null ? null : (details) => seek(details.globalPosition),
          onHorizontalDragUpdate: onSeek == null ? null : (details) => seek(details.globalPosition),
          child: SizedBox(
            height: 18,
            child: Align(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  value: progress,
                  backgroundColor: inactiveColor,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _FileAttachmentBubble extends StatefulWidget {
  const _FileAttachmentBubble({
    required this.message,
    required this.colors,
  });

  final WisperBotMessage message;
  final WisperBotResolvedTheme colors;

  @override
  State<_FileAttachmentBubble> createState() => _FileAttachmentBubbleState();
}

class _FileAttachmentBubbleState extends State<_FileAttachmentBubble> {
  bool _isOpening = false;

  Future<void> _handleOpen() async {
    if (_isOpening) return;
    setState(() => _isOpening = true);
    try {
      final filename = _resolveDocumentFilename(widget.message);
      await _openDocumentAttachment(
        context,
        filename: filename,
        attachment: widget.message.attachment,
        upload: widget.message.localUpload,
      );
    } finally {
      if (mounted) setState(() => _isOpening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisitor = widget.message.role == WisperBotMessageRole.visitor;
    final textColor = isVisitor ? widget.colors.onVisitorBubble : widget.colors.onAgentBubble;
    final muted = textColor.withValues(alpha: 0.72);
    final surface = textColor.withValues(alpha: isVisitor ? 0.13 : 0.06);
    final failed = widget.message.status == WisperBotMessageStatus.failed ||
        widget.message.status == WisperBotMessageStatus.unconfirmed;

    final filename = _resolveDocumentFilename(widget.message);
    final ext = _documentExtension(filename);
    final (icon, badgeColor) = _documentIconAndColor(ext);
    final iconColor = isVisitor ? Colors.white : badgeColor;
    final iconBackground =
        isVisitor ? Colors.white.withValues(alpha: 0.22) : badgeColor.withValues(alpha: 0.15);
    final displayName = filename.toUpperCase().endsWith('($ext)') ? filename : '$filename ($ext)';
    final sizeBytes = widget.message.localUpload?.bytes.length;
    final hasSource = widget.message.attachment?.url != null || widget.message.localUpload != null;

    return Semantics(
      button: hasSource,
      label: '$filename, $ext document, tap to download or open',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: hasSource && !_isOpening ? _handleOpen : null,
          child: Container(
            key: widget.message.localUpload != null && widget.message.attachment == null
                ? const ValueKey<String>('wisperbot-local-file-preview')
                : null,
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: _isOpening
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: iconColor,
                            ),
                          )
                        : Icon(
                            icon,
                            color: iconColor,
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          decoration: hasSource ? TextDecoration.underline : null,
                          decorationColor: textColor.withValues(alpha: 0.45),
                        ),
                      ),
                      if (sizeBytes != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(sizeBytes),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasSource)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _downloadAttachmentToDevice(
                        context,
                        filename: filename,
                        attachment: widget.message.attachment,
                        upload: widget.message.localUpload,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.download_rounded,
                          color: textColor.withValues(alpha: 0.85),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                if (failed)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.error_outline,
                      color: widget.colors.error,
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openDocumentAttachment(
  BuildContext context, {
  required String filename,
  WisperBotAttachment? attachment,
  WisperBotUpload? upload,
}) async {
  try {
    if (upload != null) {
      final wisperbotTemp = Directory('${Directory.systemTemp.path}/wisperbot');
      if (!await wisperbotTemp.exists()) {
        await wisperbotTemp.create(recursive: true);
      }
      final tempFile = File('${wisperbotTemp.path}/$filename');
      await tempFile.writeAsBytes(upload.bytes);
      final launched = await launchUrl(
        Uri.file(tempFile.path),
        mode: LaunchMode.platformDefault,
      );
      if (launched) return;
    }

    if (attachment != null) {
      final launched = await launchUrl(
        attachment.url,
        mode: LaunchMode.externalApplication,
      );
      if (launched) return;
    }

    if (context.mounted) {
      await _downloadAttachmentToDevice(
        context,
        filename: filename,
        attachment: attachment,
        upload: upload,
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open document.'),
        ),
      );
    }
  }
}

Future<void> _downloadAttachmentToDevice(
  BuildContext context, {
  required String filename,
  WisperBotAttachment? attachment,
  WisperBotUpload? upload,
}) async {
  try {
    Uint8List? bytes = upload?.bytes;
    if (bytes == null && attachment != null) {
      final request = await HttpClient().getUrl(attachment.url);
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      }
    }

    if (bytes == null || bytes.isEmpty) {
      if (attachment != null) {
        await launchUrl(attachment.url, mode: LaunchMode.externalApplication);
        return;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not download file.'),
          ),
        );
      }
      return;
    }

    String? savedPath;

    // Strategy 1: Save directly into standard "wisperbot" folder inside Downloads
    final candidateParentDirs = <Directory>[
      if (Platform.isAndroid) ...[
        Directory('/storage/emulated/0/Download'),
        Directory('/storage/emulated/0/Downloads'),
        Directory('/sdcard/Download'),
      ],
      if (Platform.isMacOS || Platform.isLinux) ...[
        if (Platform.environment['HOME'] != null)
          Directory('${Platform.environment['HOME']}/Downloads'),
      ],
      if (Platform.isWindows) ...[
        if (Platform.environment['USERPROFILE'] != null)
          Directory('${Platform.environment['USERPROFILE']}\\Downloads'),
      ],
    ];

    for (final baseDir in candidateParentDirs) {
      try {
        if (await baseDir.exists()) {
          final wisperbotDir = Directory('${baseDir.path}/wisperbot');
          if (!await wisperbotDir.exists()) {
            await wisperbotDir.create(recursive: true);
          }
          final targetFile = File('${wisperbotDir.path}/$filename');
          await targetFile.writeAsBytes(bytes);
          savedPath = targetFile.path;
          break;
        }
      } catch (_) {}
    }

    // Strategy 2: Use file_selector save location (Desktop / iOS / supported platforms)
    if (savedPath == null) {
      try {
        final saveLocation = await getSaveLocation(suggestedName: filename);
        if (saveLocation != null) {
          final file = File(saveLocation.path);
          await file.writeAsBytes(bytes);
          savedPath = file.path;
        }
      } catch (_) {}
    }

    // Strategy 3: Save to system temp / documents and launch
    if (savedPath == null) {
      try {
        final wisperbotTemp = Directory('${Directory.systemTemp.path}/wisperbot');
        if (!await wisperbotTemp.exists()) {
          await wisperbotTemp.create(recursive: true);
        }
        final tempFile = File('${wisperbotTemp.path}/$filename');
        await tempFile.writeAsBytes(bytes);
        savedPath = tempFile.path;
        await launchUrl(Uri.file(tempFile.path), mode: LaunchMode.platformDefault);
      } catch (_) {}
    }

    if (savedPath != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File saved to wisperbot: $filename'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } else {
      // Strategy 4: Fallback to external application/browser downloader
      if (attachment != null) {
        await launchUrl(attachment.url, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save file.'),
          ),
        );
      }
    }
  } catch (_) {
    try {
      if (attachment != null) {
        await launchUrl(attachment.url, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Download failed.'),
        ),
      );
    }
  }
}

String _duration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _resolveDocumentFilename(WisperBotMessage message) {
  var name = message.attachment?.filename?.trim() ?? message.localUpload?.filename.trim() ?? '';
  if (name.isEmpty && message.attachment?.url != null) {
    final segments = message.attachment!.url.pathSegments;
    if (segments.isNotEmpty && segments.last.contains('.')) {
      name = segments.last.split('?').first;
    }
  }
  if (name.isEmpty) {
    final body = message.body.trim();
    if (body.contains('.') && !body.contains('\n') && body.length < 80) {
      name = body;
    } else {
      name = 'document.pdf';
    }
  }
  return name;
}

String _visibleMessageBody(WisperBotMessage message) {
  final body = message.body.trim();
  final attachment = message.attachment;
  final localUpload = message.localUpload;
  final filename = attachment?.filename ?? localUpload?.filename;
  if (message.type == WisperBotMessageType.audio ||
      _isAudioAttachment(
        filename: filename,
        mimeType: attachment?.mimeType ?? localUpload?.mimeType,
        url: attachment?.url,
      )) {
    if (body.isEmpty ||
        body == filename ||
        body.toLowerCase() == 'voice message' ||
        body.toLowerCase() == 'audio message') {
      return '';
    }
    final filenamePattern = RegExp(
      r'\.(m4a|mp3|wav|webm|aac|ogg|oga|opus|amr)$',
      caseSensitive: false,
    );
    return filenamePattern.hasMatch(body) ? '' : body;
  }
  if (message.type == WisperBotMessageType.file || (attachment != null || localUpload != null)) {
    if (body.isEmpty ||
        body == filename ||
        body.toLowerCase() == 'document attachment' ||
        body.toLowerCase() == 'file attachment' ||
        body == 'document.pdf' ||
        body.toLowerCase().endsWith('.pdf') ||
        body.toLowerCase().endsWith('.docx') ||
        body.toLowerCase().endsWith('.xlsx') ||
        body.toLowerCase().endsWith('.pptx') ||
        body.toLowerCase().endsWith('.txt') ||
        body.toLowerCase().endsWith('.zip')) {
      return '';
    }
  }
  return body;
}
