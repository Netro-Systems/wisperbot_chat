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
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;
  bool _mediaBusy = false;
  bool _isRecording = false;
  WisperBotUpload? _pendingImage;
  WisperBotUpload? _pendingAudio;

  @override
  Widget build(BuildContext context) {
    final mediaAdapter = widget.mediaAdapter;
    final showImage = mediaAdapter != null && widget.imagesEnabled;
    final showAudio = mediaAdapter != null && widget.audioEnabled;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.colors.surface,
        border: Border(top: BorderSide(color: widget.colors.outline)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 9, 9, 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (_pendingImage != null)
              _ImagePreview(
                upload: _pendingImage!,
                colors: widget.colors,
                sending: _mediaBusy,
                onSend: _sendPendingImage,
                onDiscard: _discardPendingImage,
              ),
            if (_pendingAudio != null)
              _AudioPreview(
                upload: _pendingAudio!,
                colors: widget.colors,
                sending: _mediaBusy,
                onSend: _sendPendingAudio,
                onDiscard: _discardPendingAudio,
              ),
            if (_isRecording)
              _RecordingStatus(
                colors: widget.colors,
                onCancel: _mediaBusy ? null : _cancelRecording,
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                if (showImage)
                  Semantics(
                    button: true,
                    label: 'Attach image',
                    child: IconButton(
                      tooltip: 'Attach image',
                      onPressed:
                          _mediaBusy || _isRecording || _pendingAudio != null
                              ? null
                              : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      color: widget.colors.onSurfaceMuted,
                    ),
                  ),
                if (showAudio)
                  Semantics(
                    button: true,
                    label: _isRecording
                        ? 'Stop voice recording'
                        : 'Record voice message',
                    child: IconButton(
                      tooltip: _isRecording
                          ? 'Stop voice recording'
                          : 'Record voice message',
                      onPressed: _mediaBusy ||
                              _pendingImage != null ||
                              _pendingAudio != null
                          ? null
                          : _toggleRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_none,
                      ),
                      color: _isRecording
                          ? widget.colors.error
                          : widget.colors.onSurfaceMuted,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    maxLength: 4000,
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Type your message…',
                      hintStyle: TextStyle(color: widget.colors.onSurfaceMuted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 13,
                      ),
                    ),
                    onChanged: _onTextChanged,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 6),
                Semantics(
                  button: true,
                  label: 'Send message',
                  child: IconButton.filled(
                    style: IconButton.styleFrom(
                      minimumSize: const Size.square(48),
                      backgroundColor: widget.colors.primary,
                      foregroundColor: widget.colors.onPrimary,
                      disabledBackgroundColor: widget.colors.surfaceMuted,
                      disabledForegroundColor: widget.colors.onSurfaceMuted,
                    ),
                    tooltip: 'Send message',
                    onPressed: _hasText &&
                            !_mediaBusy &&
                            !_isRecording &&
                            _pendingImage == null &&
                            _pendingAudio == null
                        ? _send
                        : null,
                    icon: const Icon(Icons.send_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onTextChanged(String value) {
    final hasText = value.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    unawaited(widget.controller.setTyping(hasText));
  }

  Future<void> _pickImage() async {
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
    WisperBotDebugUploadLogger.selectionStarted();
    setState(() => _mediaBusy = true);
    try {
      final upload = await adapter.pickImage();
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
    setState(() => _mediaBusy = true);
    try {
      final caption = _textController.text.trim();
      await widget.controller.sendImage(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      WisperBotDebugUploadLogger.sendConfirmed();
      if (!mounted) return;
      _textController.clear();
      setState(() {
        _hasText = false;
        _pendingImage = null;
      });
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
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
    setState(() => _mediaBusy = true);
    try {
      if (!_isRecording) {
        await adapter.startAudioRecording();
        if (mounted) setState(() => _isRecording = true);
        return;
      }

      final upload = await adapter.stopAudioRecording();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (upload == null) return;
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
        setState(() => _isRecording = false);
        _showMediaError(error, 'The voice message could not be recorded.');
      }
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _sendPendingAudio() async {
    final upload = _pendingAudio;
    if (upload == null) return;
    setState(() => _mediaBusy = true);
    try {
      final caption = _textController.text.trim();
      await widget.controller.sendAudio(
        upload,
        caption: caption.isEmpty ? null : caption,
      );
      if (!mounted) return;
      _textController.clear();
      setState(() {
        _hasText = false;
        _pendingAudio = null;
      });
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
    final adapter = widget.mediaAdapter;
    if (adapter == null) return;
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
    final adapter = widget.mediaAdapter;
    if (_isRecording && adapter != null) {
      unawaited(adapter.cancelAudioRecording().catchError((_) {}));
    }
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _RecordingStatus extends StatelessWidget {
  const _RecordingStatus({required this.colors, required this.onCancel});

  final WisperBotResolvedTheme colors;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        label: 'Recording voice message',
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: <Widget>[
              Icon(Icons.fiber_manual_record, size: 14, color: colors.error),
              const SizedBox(width: 6),
              const Expanded(child: Text('Recording… tap stop to preview')),
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
            ],
          ),
        ),
      );
}
