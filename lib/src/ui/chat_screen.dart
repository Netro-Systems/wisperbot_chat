import 'dart:async';

import 'package:flutter/material.dart';

import '../application/chat_runtime.dart';
import '../domain/config.dart';
import '../domain/models.dart';
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
  StreamSubscription<WisperBotChatState>? _subscription;
  late WisperBotChatState _state;
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
    _state = _controller.state;
    _subscription = _controller.states.listen((state) {
      if (mounted) setState(() => _state = state);
    });
    _controller.handlePresentationOpened();
    unawaited(_controller.initialize().catchError((_) {}));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: widget.appBar ??
            AppBar(
              title: Text(
                _state.widget?.title.trim().isNotEmpty == true
                    ? _state.widget!.title
                    : 'Chat with us',
              ),
            ),
        body: WisperBotChatView(
          config: widget.config,
          controller: _controller,
          showHeader: false,
        ),
      );

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
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
