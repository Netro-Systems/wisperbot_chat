import 'dart:async';

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import 'chat_view.dart';

class WisperBotChatScreen extends StatefulWidget {
  const WisperBotChatScreen({
    super.key,
    required this.config,
    this.controller,
    this.appBar,
    this.onClosed,
  });

  final WisperBotConfig config;
  final WisperBotChatController? controller;
  final PreferredSizeWidget? appBar;
  final ValueChanged<WisperBotChatCloseReason>? onClosed;

  @override
  State<WisperBotChatScreen> createState() => _WisperBotChatScreenState();
}

class _WisperBotChatScreenState extends State<WisperBotChatScreen> {
  late WisperBotChatController _controller;
  WisperBotClient? _ownedClient;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied == null) {
      final client = WisperBotClient(config: widget.config);
      _ownedClient = client;
      _controller = WisperBotChatController(client: client);
    } else {
      _controller = supplied;
    }
    _controller.handlePresentationOpened();
  }

  @override
  Widget build(BuildContext context) {
    final usesBrandedHeader = widget.appBar == null;
    final navigator = Navigator.of(context);
    return Scaffold(
      appBar: widget.appBar,
      body: WisperBotChatView(
        config: widget.config,
        controller: _controller,
        showHeader: usesBrandedHeader,
        onClose: usesBrandedHeader && navigator.canPop()
            ? () => navigator.maybePop()
            : null,
      ),
    );
  }

  void _notifyClosed() {
    if (_closed) return;
    _closed = true;
    const reason = WisperBotChatCloseReason.userClosed;
    _controller.handlePresentationClosed(reason);
    widget.onClosed?.call(reason);
  }

  @override
  void dispose() {
    _notifyClosed();
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
