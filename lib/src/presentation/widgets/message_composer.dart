part of '../view/chat_view.dart';

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.colors,
    required this.mediaAdapter,
    required this.imagesEnabled,
    required this.audioEnabled,
  });

  final WisperBotChatController controller;
  final WisperBotResolvedTheme colors;
  final WisperBotMediaAdapter? mediaAdapter;
  final bool imagesEnabled;
  final bool audioEnabled;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  static const String _microphoneIcon = 'assets/icons/microphone.png';
  static const String _sendIcon = 'assets/icons/send.png';

  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  _DefaultMediaAdapter? _ownedMediaAdapter;
  Timer? _recordingTimer;
  Duration _recordingElapsed = Duration.zero;
  bool _hasText = false;
  bool _mediaBusy = false;
  bool _isRecording = false;
  WisperBotUpload? _pendingImage;
  WisperBotUpload? _pendingFile;
  WisperBotUpload? _pendingAudio;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        border: Border(top: BorderSide(color: widget.colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_pendingImage != null)
              _ImagePreview(
                upload: _pendingImage!,
                colors: widget.colors,
                sending: _mediaBusy,
                onDiscard: _discardPendingImage,
              ),
            if (_pendingFile != null)
              _FilePreview(
                upload: _pendingFile!,
                colors: widget.colors,
                sending: _mediaBusy,
                onDiscard: _discardPendingFile,
              ),
            if (_pendingAudio != null)
              _AudioPreview(
                upload: _pendingAudio!,
                colors: widget.colors,
                sending: _mediaBusy,
                onDiscard: _discardPendingAudio,
              ),
            if (_isRecording)
              _RecordingComposer(
                colors: widget.colors,
                elapsed: _recordingElapsed,
                busy: _mediaBusy,
                onCancel: _cancelRecording,
                onSend: _sendRecording,
              )
            else
              _TextComposer(
                colors: widget.colors,
                textController: _textController,
                focusNode: _focusNode,
                showImage: widget.imagesEnabled,
                showAudio: widget.audioEnabled,
                mediaBusy: _mediaBusy,
                pendingImage: _pendingImage != null,
                pendingFile: _pendingFile != null,
                pendingAudio: _pendingAudio != null,
                canSend: _canSend,
                onAttachment: _openAttachmentPicker,
                onPickImage: _pickImage,
                onToggleRecording: _toggleRecording,
                onTextChanged: _onTextChanged,
                onSend: _send,
              ),
          ],
        ),
      ),
    );
  }

  void _startRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingElapsed = Duration.zero;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      }
    });
  }

  void _stopRecordingTimer() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _recordingElapsed = Duration.zero;
  }

  Future<WisperBotUpload?> _stopRecordingForUpload() async {
    final upload = await _mediaAdapter.stopAudioRecording();
    if (!mounted) return null;
    setState(() {
      _isRecording = false;
      _stopRecordingTimer();
    });
    return upload;
  }

  Future<void> _sendRecording() async {
    if (!_isRecording || _mediaBusy) return;
    setState(() => _mediaBusy = true);
    try {
      final upload = await _stopRecordingForUpload();
      if (!mounted || upload == null) return;
      await widget.controller.sendAudio(upload);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _stopRecordingTimer();
        });
        _showMediaError(error, 'The voice message could not be sent.');
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    unawaited(widget.controller.setTyping(hasText));
  }

  WisperBotMediaAdapter get _mediaAdapter =>
      widget.mediaAdapter ?? (_ownedMediaAdapter ??= _DefaultMediaAdapter());

  bool get _canSend =>
      !_mediaBusy &&
      !_isRecording &&
      (_hasText ||
          _pendingImage != null ||
          _pendingFile != null ||
          _pendingAudio != null);

  Future<void> _openAttachmentPicker() async {
    if (_mediaBusy || _isRecording) return;
    final option = await showModalBottomSheet<AttachmentOption>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AttachmentPickerSheet(
        showDocument: true,
        showCamera: widget.imagesEnabled,
        showGallery: widget.imagesEnabled,
        showAudio: widget.audioEnabled,
      ),
    );

    if (option == null || !mounted) return;

    switch (option) {
      case AttachmentOption.camera:
        await _pickImage(source: ImageSource.camera);
      case AttachmentOption.gallery:
        await _pickImage(source: ImageSource.gallery);
      case AttachmentOption.audio:
        await _toggleRecording();
      case AttachmentOption.document:
        await _pickDocument();
    }
  }

  Future<void> _pickDocument() async {
    final adapter = _mediaAdapter;
    WisperBotDebugUploadLogger.selectionStarted();
    setState(() => _mediaBusy = true);
    try {
      final upload = await adapter.pickDocument();
      if (!mounted) return;
      if (upload == null) {
        WisperBotDebugUploadLogger.selectionCancelled();
      } else {
        WisperBotDebugUploadLogger.selectionReady(
          sizeBytes: upload.bytes.length,
          mimeType: upload.mimeType,
        );
        setState(() => _pendingFile = upload);
      }
    } on Object catch (error) {
      WisperBotDebugUploadLogger.selectionFailed(error);
      if (mounted) _showMediaError(error, 'The document could not be selected.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _sendPendingFile() async {
    final upload = _pendingFile;
    if (upload == null) return;
    WisperBotDebugUploadLogger.sendRequested(
      sizeBytes: upload.bytes.length,
      mimeType: upload.mimeType,
    );
    final caption = _textController.text.trim();
    _textController.clear();
    setState(() {
      _mediaBusy = true;
      _hasText = false;
      _pendingFile = null;
    });
    try {
      await widget.controller.sendFile(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      WisperBotDebugUploadLogger.sendConfirmed();
    } on Object catch (error) {
      if (error is WisperBotException) {
        WisperBotDebugUploadLogger.failed('file_upload', error);
      } else {
        WisperBotDebugUploadLogger.unexpectedFailure('file_upload', error);
      }
      if (mounted) _showMediaError(error, 'The file could not be sent.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  void _discardPendingFile() => setState(() => _pendingFile = null);

  Future<void> _pickImage({ImageSource source = ImageSource.gallery}) async {
    final adapter = _mediaAdapter;
    WisperBotDebugUploadLogger.selectionStarted();
    setState(() => _mediaBusy = true);
    try {
      final upload = adapter is _DefaultMediaAdapter
          ? await adapter.pickImage(source: source)
          : await adapter.pickImage();
      if (!mounted) return;
      if (upload == null) {
        WisperBotDebugUploadLogger.selectionCancelled();
      } else {
        WisperBotDebugUploadLogger.selectionReady(
          sizeBytes: upload.bytes.length,
          mimeType: upload.mimeType,
        );
        setState(() => _pendingImage = upload);
      }
    } on Object catch (error) {
      WisperBotDebugUploadLogger.selectionFailed(error);
      if (mounted) _showMediaError(error, 'The image could not be selected.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _sendPendingImage() async {
    final upload = _pendingImage;
    if (upload == null) return;
    WisperBotDebugUploadLogger.sendRequested(
      sizeBytes: upload.bytes.length,
      mimeType: upload.mimeType,
    );
    final caption = _textController.text.trim();
    _textController.clear();
    setState(() {
      _mediaBusy = true;
      _hasText = false;
      _pendingImage = null;
    });
    try {
      await widget.controller.sendImage(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      WisperBotDebugUploadLogger.sendConfirmed();
    } on Object catch (error) {
      if (error is WisperBotException) {
        WisperBotDebugUploadLogger.failed('image_upload', error);
      } else {
        WisperBotDebugUploadLogger.unexpectedFailure('image_upload', error);
      }
      if (mounted) _showMediaError(error, 'The image could not be sent.');
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  void _discardPendingImage() => setState(() => _pendingImage = null);

  Future<void> _toggleRecording() async {
    final adapter = _mediaAdapter;
    setState(() => _mediaBusy = true);
    try {
      if (!_isRecording) {
        await adapter.startAudioRecording();
        if (mounted) {
          setState(() {
            _isRecording = true;
            _startRecordingTimer();
          });
        }
        return;
      }

      final upload = await _stopRecordingForUpload();
      if (!mounted || upload == null) return;
      setState(() => _pendingAudio = upload);
    } on Object catch (error) {
      if (_isRecording) {
        try {
          await adapter.cancelAudioRecording();
        } on Object {
          // Preserve the original error for the visitor.
        }
      }
      if (mounted) {
        setState(() {
          _isRecording = false;
          _stopRecordingTimer();
        });
        _showMediaError(error, 'The voice message could not be recorded.');
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _sendPendingAudio() async {
    final upload = _pendingAudio;
    if (upload == null) return;
    final caption = _textController.text.trim();
    _textController.clear();
    setState(() {
      _mediaBusy = true;
      _hasText = false;
      _pendingAudio = null;
    });
    try {
      await widget.controller.sendAudio(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
    } on Object catch (error) {
      if (mounted) {
        _showMediaError(error, 'The voice message could not be sent.');
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  void _discardPendingAudio() => setState(() => _pendingAudio = null);

  Future<void> _cancelRecording() async {
    final adapter = _mediaAdapter;
    setState(() => _mediaBusy = true);
    try {
      await adapter.cancelAudioRecording();
    } on Object catch (error) {
      if (mounted) _showMediaError(error, 'Recording could not be cancelled.');
    } finally {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _mediaBusy = false;
          _stopRecordingTimer();
        });
      }
    }
  }

  void _showMediaError(Object error, String fallback) {
    final message = error is WisperBotException ? error.message : fallback;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _send() {
    if (_pendingImage != null) {
      unawaited(_sendPendingImage());
      return;
    }
    if (_pendingFile != null) {
      unawaited(_sendPendingFile());
      return;
    }
    if (_pendingAudio != null) {
      unawaited(_sendPendingAudio());
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _hasText = false);
    unawaited(_sendMessage(text));
  }

  Future<void> _sendMessage(String text) async {
    try {
      await widget.controller.sendText(text);
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is WisperBotException
          ? error.message
          : 'The message could not be sent.';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    final adapter = widget.mediaAdapter ?? _ownedMediaAdapter;
    if (_isRecording && adapter != null) {
      unawaited(adapter.cancelAudioRecording().catchError((_) {}));
    }
    _recordingTimer?.cancel();
    final owned = _ownedMediaAdapter;
    if (owned != null) {
      unawaited(owned.dispose());
    }
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _TextComposer extends StatelessWidget {
  const _TextComposer({
    required this.colors,
    required this.textController,
    required this.focusNode,
    required this.showImage,
    required this.showAudio,
    required this.mediaBusy,
    required this.pendingImage,
    required this.pendingFile,
    required this.pendingAudio,
    required this.canSend,
    required this.onAttachment,
    required this.onPickImage,
    required this.onToggleRecording,
    required this.onTextChanged,
    required this.onSend,
  });

  final WisperBotResolvedTheme colors;
  final TextEditingController textController;
  final FocusNode focusNode;
  final bool showImage;
  final bool showAudio;
  final bool mediaBusy;
  final bool pendingImage;
  final bool pendingFile;
  final bool pendingAudio;
  final bool canSend;
  final VoidCallback onAttachment;
  final VoidCallback onPickImage;
  final VoidCallback onToggleRecording;
  final ValueChanged<String> onTextChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final mediaIconColor = colors.onSurface;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 86),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: textController,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 4,
              maxLength: 4000,
              buildCounter: (_,
                      {required currentLength,
                      required isFocused,
                      maxLength}) =>
                  null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your message…',
                hintStyle: TextStyle(
                  color: colors.onSurfaceMuted,
                  fontWeight: FontWeight.w400,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              ),
              onChanged: onTextChanged,
              onSubmitted: (_) => onSend(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 6, 4),
            child: Row(
              children: <Widget>[
                if (showImage)
                  _ComposerIconButton(
                    tooltip: 'Attach file',
                    semanticLabel: 'Attach file',
                    onPressed: mediaBusy || pendingAudio ? null : onAttachment,
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: mediaIconColor,
                      size: 22,
                    ),
                  ),
                SizedBox(width: showImage && showAudio ? 8 : 0),
                if (showAudio)
                  _ComposerIconButton(
                    tooltip: 'Record voice message',
                    semanticLabel: 'Record voice message',
                    onPressed: mediaBusy ||
                            pendingImage ||
                            pendingFile ||
                            pendingAudio
                        ? null
                        : onToggleRecording,
                    padding: EdgeInsets.zero,
                    icon: _ComposerAssetIcon(
                      assetName: _ComposerState._microphoneIcon,
                      color: mediaIconColor,
                      size: 21,
                    ),
                  ),
                const Spacer(),
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: canSend ? onSend : null,
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(42),
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      disabledBackgroundColor: colors.surfaceMuted,
                      disabledForegroundColor: colors.onSurfaceMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _ComposerAssetIcon(
                      assetName: _ComposerState._sendIcon,
                      color: canSend ? colors.onPrimary : colors.onSurfaceMuted,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingComposer extends StatelessWidget {
  const _RecordingComposer({
    required this.colors,
    required this.elapsed,
    required this.busy,
    required this.onCancel,
    required this.onSend,
  });

  final WisperBotResolvedTheme colors;
  final Duration elapsed;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: 'Recording voice message',
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _RecordingWaveform(color: colors.onSurfaceMuted),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                _ComposerIconButton(
                  tooltip: 'Cancel recording',
                  semanticLabel: 'Cancel recording',
                  onPressed: busy ? null : onCancel,
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.error,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: colors.error,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.graphic_eq, color: colors.onPrimary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _formatRecordingDuration(elapsed),
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: colors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton.filled(
                  tooltip: 'Send voice message',
                  onPressed: busy ? null : onSend,
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(42),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                    disabledBackgroundColor: colors.surface,
                    disabledForegroundColor: colors.onSurfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _ComposerAssetIcon(
                    assetName: _ComposerState._sendIcon,
                    color: colors.onPrimary,
                    size: 21,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingWaveform extends StatefulWidget {
  const _RecordingWaveform({required this.color});

  final Color color;

  @override
  State<_RecordingWaveform> createState() => _RecordingWaveformState();
}

class _RecordingWaveformState extends State<_RecordingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 12,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _RecordingWaveformPainter(
              color: widget.color,
              progress: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _RecordingWaveformPainter extends CustomPainter {
  const _RecordingWaveformPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 64;
    const barWidth = 2.0;
    final gap = size.width <= barCount * barWidth
        ? 2.0
        : (size.width - (barCount * barWidth)) / (barCount - 1);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = barWidth;

    for (var index = 0; index < barCount; index++) {
      final phase = (progress * math.pi * 2) + (index * 0.42);
      final secondary = math.sin((progress * math.pi * 4) + (index * 0.19));
      final normalized = (math.sin(phase) + 1) / 2;
      final heightFactor = (normalized * 0.65) + (secondary.abs() * 0.25);
      final barHeight = 3 + (heightFactor.clamp(0.0, 1.0) * (size.height - 3));
      final x = index * (barWidth + gap) + (barWidth / 2);
      final y1 = (size.height - barHeight) / 2;
      final y2 = y1 + barHeight;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RecordingWaveformPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.progress != progress;
}

class _ComposerIconButton extends StatelessWidget {
  const _ComposerIconButton({
    required this.tooltip,
    required this.semanticLabel,
    required this.icon,
    required this.onPressed,
    this.padding = EdgeInsets.zero,
  });

  final String tooltip;
  final String semanticLabel;
  final Widget icon;
  final VoidCallback? onPressed;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 28,
            height: 32,
            padding: padding,
            alignment: Alignment.center,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _ComposerAssetIcon extends StatelessWidget {
  const _ComposerAssetIcon({
    required this.assetName,
    required this.color,
    this.size = 16,
  });

  final String assetName;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      color: color,
      package: 'wisperbot_chat',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

String _formatRecordingDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
