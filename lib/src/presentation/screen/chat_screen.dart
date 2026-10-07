import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/wisperbot_runtime.dart';
import '../../domain/events/chat_event.dart';
import '../facade/wisperbot_chat.dart';
import '../view/chat_view.dart';

/// Full-screen scaffold integration for the prebuilt chat experience.
class WisperBotChatScreen extends StatefulWidget {
  /// Creates a full-screen chat.
  ///
  /// When [controller] is omitted, the initialized shared runtime is used.
  const WisperBotChatScreen({
    super.key,
    this.controller,
    this.appBar,
    this.onClosed,
  });

  /// Optional host-owned controller.
  final WisperBotChatController? controller;

  /// Optional host-owned app bar replacing the built-in header.
  final PreferredSizeWidget? appBar;

  /// Called once when this presentation closes.
  final ValueChanged<WisperBotChatCloseReason>? onClosed;

  @override
  State<WisperBotChatScreen> createState() => _WisperBotChatScreenState();
}

class _WisperBotChatScreenState extends State<WisperBotChatScreen> {
  late WisperBotChatController _controller;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied != null) {
      _controller = supplied;
    } else {
      _controller = WisperBotChat.requireDefaultController();
    }
    _controller.handlePresentationOpened();
  }

  @override
  Widget build(BuildContext context) {
    final usesBrandedHeader = widget.appBar == null;
    final navigator = Navigator.of(context);
    final lightStatusBarIcons = _controller.runtimeLightStatusBarIcons;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            lightStatusBarIcons ? Brightness.light : Brightness.dark,
        statusBarBrightness:
            lightStatusBarIcons ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        appBar: widget.appBar,
        body: WisperBotChatView(
          controller: _controller,
          showHeader: usesBrandedHeader,
          onClose: usesBrandedHeader && navigator.canPop()
              ? () => navigator.maybePop()
              : null,
        ),
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
    super.dispose();
  }
}
