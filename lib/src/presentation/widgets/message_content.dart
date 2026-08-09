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
        if (message.type == WisperBotMessageType.audio && attachment != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AudioAttachmentPlayer(
              attachment: attachment,
              colors: colors,
              visitor: message.role == WisperBotMessageRole.visitor,
              loadAttachmentBytes: controller.loadAttachmentBytes,
            ),
          ),
        if (_visibleMessageBody(message).isNotEmpty)
          SelectableText(
            _visibleMessageBody(message),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: textColor, height: 1.4),
          ),
      ],
    );
  }
}

class _AudioAttachmentPlayer extends StatefulWidget {
  const _AudioAttachmentPlayer({
    required this.attachment,
    required this.colors,
    required this.visitor,
    required this.loadAttachmentBytes,
  });

  final WisperBotAttachment attachment;
  final WisperBotResolvedTheme colors;
  final bool visitor;
  final Future<Uint8List> Function(WisperBotAttachment attachment)
      loadAttachmentBytes;

  @override
  State<_AudioAttachmentPlayer> createState() => _AudioAttachmentPlayerState();
}

class _AudioAttachmentPlayerState extends State<_AudioAttachmentPlayer> {
  static final Map<Uri, Future<Uint8List>> _downloadCache =
      <Uri, Future<Uint8List>>{};

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
    if (oldWidget.attachment.url != widget.attachment.url) {
      unawaited(_loadAudio());
    }
  }

  Future<void> _loadAudio() async {
    setState(() {
      _ready = false;
      _failed = false;
    });

    try {
      final bytes = await _cachedAttachmentBytes();
      await _setAudioSourceWithFallbacks(bytes);
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<Uint8List> _cachedAttachmentBytes() async {
    final future = _downloadCache.putIfAbsent(
      widget.attachment.url,
      () => widget.loadAttachmentBytes(widget.attachment),
    );
    try {
      return await future;
    } on Object {
      _downloadCache.remove(widget.attachment.url);
      rethrow;
    }
  }

  Future<void> _setAudioSourceWithFallbacks(Uint8List bytes) async {
    Object? lastError;
    for (final contentType in _candidateAudioContentTypes(widget.attachment)) {
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
    final foreground = widget.visitor
        ? widget.colors.onVisitorBubble
        : widget.colors.onAgentBubble;
    final muted = foreground.withValues(alpha: 0.72);
    final trackColor = foreground.withValues(alpha: 0.18);
    final accent = widget.visitor ? foreground : widget.colors.primary;
    final surface = foreground.withValues(alpha: widget.visitor ? 0.13 : 0.06);

    if (_failed) {
      return Container(
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
                  tooltip:
                      playing ? 'Pause voice message' : 'Play voice message',
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
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
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
                          onSeek: loading || duration == Duration.zero
                              ? null
                              : _player.seek,
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
                              duration == Duration.zero
                                  ? '--:--'
                                  : _duration(duration),
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

bool _validAudioMimeType(String? value) {
  final normalized = value?.trim().toLowerCase();
  return normalized != null &&
      normalized.isNotEmpty &&
      normalized.startsWith('audio/');
}

String? _inferAudioMimeType(String? filenameOrPath) {
  final ext =
      (filenameOrPath ?? '').split('?').first.split('.').last.toLowerCase();
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
          onTapDown:
              onSeek == null ? null : (details) => seek(details.globalPosition),
          onHorizontalDragUpdate:
              onSeek == null ? null : (details) => seek(details.globalPosition),
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

String _duration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

String _visibleMessageBody(WisperBotMessage message) {
  final body = message.body.trim();
  final attachment = message.attachment;
  if (message.type != WisperBotMessageType.audio) return body;
  if (body.isEmpty ||
      body == attachment?.filename ||
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
