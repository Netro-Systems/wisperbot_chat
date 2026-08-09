part of '../view/chat_view.dart';

/// Internal audio confirmation shown before an upload is dispatched.
class _AudioPreview extends StatefulWidget {
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
  State<_AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<_AudioPreview> {
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
    unawaited(_loadPreview());
  }

  @override
  void didUpdateWidget(covariant _AudioPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.upload, widget.upload)) {
      unawaited(_loadPreview());
    }
  }

  Future<void> _loadPreview() async {
    setState(() {
      _ready = false;
      _failed = false;
    });

    try {
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.dataFromBytes(
            widget.upload.bytes,
            mimeType: widget.upload.mimeType,
          ),
        ),
      );
      if (mounted) setState(() => _ready = true);
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
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
  Widget build(BuildContext context) => Container(
        key: const ValueKey<String>('wisperbot-audio-preview'),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: widget.colors.surfaceMuted,
          border: Border.all(color: widget.colors.outline),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snapshot) {
                final state = snapshot.data;
                final playing = state?.playing ?? false;
                final loading = !_ready ||
                    state?.processingState == ProcessingState.loading ||
                    state?.processingState == ProcessingState.buffering;
                return IconButton.filledTonal(
                  tooltip:
                      playing ? 'Pause voice preview' : 'Play voice preview',
                  onPressed: loading || _failed || widget.sending
                      ? null
                      : _togglePlayback,
                  icon: loading
                      ? const Icon(Icons.graphic_eq_rounded)
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                  style: IconButton.styleFrom(
                    foregroundColor: widget.colors.primary,
                    disabledForegroundColor: widget.colors.onSurfaceMuted,
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _failed ? 'Audio preview unavailable' : widget.upload.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: widget.sending ? null : widget.onSend,
              child: const Text('Send'),
            ),
            IconButton(
              tooltip: 'Discard voice message',
              onPressed: widget.sending ? null : widget.onDiscard,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      );
}
