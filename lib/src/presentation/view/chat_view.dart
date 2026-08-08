import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../diagnostics/debug_upload_logger.dart';
import '../../domain/contracts/media_adapter.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';
import '../media/remote_image.dart';
import '../theme/resolved_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/brand_footer.dart';
import '../widgets/availability_banner.dart';
import '../widgets/chat_error_state.dart';
import '../widgets/connection_banner.dart';

part '../widgets/loading_shimmer.dart';
part '../widgets/chat_header.dart';
part '../widgets/chat_timeline.dart';
part '../widgets/welcome_bubble.dart';
part '../widgets/pre_chat_form.dart';
part '../widgets/message_bubble.dart';
part '../widgets/message_content.dart';
part '../widgets/typing_indicator.dart';
part '../widgets/handoff_action.dart';
part '../widgets/message_composer.dart';
part '../widgets/image_preview.dart';
part '../widgets/audio_preview.dart';

/// Builds a custom chat state such as an empty or error presentation.
typedef WisperBotChatStateBuilder = Widget Function(
  BuildContext context,
  WisperBotChatState state,
);

/// Builds a custom presentation for one immutable message.
typedef WisperBotMessageBuilder = Widget Function(
  BuildContext context,
  WisperBotMessage message,
);

/// Builds a custom composer connected to the active controller and state.
typedef WisperBotComposerBuilder = Widget Function(
  BuildContext context,
  WisperBotChatController controller,
  WisperBotChatState state,
);

/// Embeddable prebuilt chat UI with no scaffold or navigation assumptions.
class WisperBotChatView extends StatefulWidget {
  /// Creates an embedded chat view.
  ///
  /// When [controller] is omitted, the view owns and disposes its runtime.
  const WisperBotChatView({
    super.key,
    required this.config,
    this.controller,
    this.showHeader = true,
    this.emptyBuilder,
    this.errorBuilder,
    this.messageBuilder,
    this.composerBuilder,
    this.onClose,
  });

  /// Widget, identity, transport, polling, and theme configuration.
  final WisperBotConfig config;

  /// Optional host-owned controller.
  final WisperBotChatController? controller;

  /// Whether the built-in branded header is visible.
  final bool showHeader;

  /// Optional replacement for the ready state with no server messages.
  final WisperBotChatStateBuilder? emptyBuilder;

  /// Optional replacement for terminal error state.
  final WisperBotChatStateBuilder? errorBuilder;

  /// Optional per-message renderer.
  final WisperBotMessageBuilder? messageBuilder;

  /// Optional composer renderer.
  final WisperBotComposerBuilder? composerBuilder;

  /// Optional close callback rendered by the built-in header.
  final VoidCallback? onClose;

  @override
  State<WisperBotChatView> createState() => _WisperBotChatViewState();
}

class _WisperBotChatViewState extends State<WisperBotChatView> {
  final ScrollController _scrollController = ScrollController();
  late WisperBotChatController _controller;
  WisperBotClient? _ownedClient;
  StreamSubscription<WisperBotChatState>? _subscription;
  late WisperBotChatState _state;
  bool _nearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_trackScrollPosition);
    _attachRuntime();
  }

  @override
  void didUpdateWidget(covariant WisperBotChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        !identical(oldWidget.config, widget.config)) {
      unawaited(_replaceRuntime());
    }
  }

  void _attachRuntime() {
    final supplied = widget.controller;
    if (supplied == null) {
      final client = WisperBotClient(config: widget.config);
      _ownedClient = client;
      _controller = WisperBotChatController(client: client);
    } else {
      _controller = supplied;
    }
    _state = _controller.state;
    _subscription = _controller.states.listen(_onState);
    unawaited(_controller.initialize().catchError((_) {}));
  }

  Future<void> _replaceRuntime() async {
    await _subscription?.cancel();
    final oldClient = _ownedClient;
    if (oldClient != null) {
      await _controller.dispose();
      await oldClient.close();
    }
    _ownedClient = null;
    if (!mounted) return;
    _attachRuntime();
    setState(() {});
  }

  void _onState(WisperBotChatState next) {
    if (!mounted) return;
    final grew = next.messages.length > _state.messages.length;
    final sentByVisitor = grew &&
        next.messages.isNotEmpty &&
        next.messages.last.role == WisperBotMessageRole.visitor;
    setState(() => _state = next);
    if (grew && (_nearBottom || sentByVisitor)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
    }
  }

  void _trackScrollPosition() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _nearBottom = position.maxScrollExtent - position.pixels < 96;
  }

  void _scrollToEnd() {
    if (!mounted || !_scrollController.hasClients) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final target = _scrollController.position.maxScrollExtent;
    if (reduceMotion) {
      _scrollController.jumpTo(target);
    } else {
      unawaited(
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hostTheme = Theme.of(context);
    final colors = WisperBotResolvedTheme.resolve(
      hostTheme: hostTheme,
      server: _state.widget,
      override: widget.config.theme,
      useApiColors: widget.config.useApiColors,
    );
    final sdkTheme = hostTheme.copyWith(
      colorScheme: hostTheme.colorScheme.copyWith(
        primary: colors.primary,
        onPrimary: colors.onPrimary,
      ),
      textSelectionTheme: hostTheme.textSelectionTheme.copyWith(
        cursorColor: colors.primary,
        selectionColor: colors.primary.withValues(alpha: 0.24),
        selectionHandleColor: colors.primary,
      ),
    );
    return Theme(
      data: sdkTheme,
      child: ColoredBox(
        color: colors.background,
        child: _isLoading(_state.phase)
            ? _ChatLoadingShimmer(showHeader: widget.showHeader)
            : Column(
                children: <Widget>[
                  if (widget.showHeader)
                    _ChatHeader(
                      state: _state,
                      colors: colors,
                      onClose: widget.onClose,
                    ),
                  if (_state.phase == WisperBotChatPhase.reconnecting)
                    ChatConnectionBanner(colors: colors),
                  if (_state.supportAvailability ==
                      WisperBotSupportAvailability.unavailable)
                    ChatAvailabilityBanner(state: _state, colors: colors),
                  Expanded(child: _buildBody(colors)),
                  if (_canCompose(_state)) _buildComposer(colors),
                ],
              ),
      ),
    );
  }

  bool _isLoading(WisperBotChatPhase phase) =>
      phase == WisperBotChatPhase.idle ||
      phase == WisperBotChatPhase.initializing ||
      phase == WisperBotChatPhase.expired;

  Widget _buildBody(WisperBotResolvedTheme colors) {
    switch (_state.phase) {
      case WisperBotChatPhase.idle:
      case WisperBotChatPhase.initializing:
      case WisperBotChatPhase.expired:
        return const SizedBox.shrink();
      case WisperBotChatPhase.awaitingPreChat:
        return _PreChatForm(
          controller: _controller,
          state: _state,
          colors: colors,
        );
      case WisperBotChatPhase.failure:
        return widget.errorBuilder?.call(context, _state) ??
            ChatErrorState(
              state: _state,
              colors: colors,
              onRetry: _state.error?.retryable == true
                  ? () => unawaited(
                        _controller.initialize().catchError((_) {}),
                      )
                  : null,
            );
      case WisperBotChatPhase.ready:
      case WisperBotChatPhase.reconnecting:
        if (_state.messages.isEmpty) {
          final custom = widget.emptyBuilder?.call(context, _state);
          if (custom != null) return custom;
        }
        return _timeline(colors);
      case WisperBotChatPhase.disposed:
        return const SizedBox.shrink();
    }
  }

  Widget _timeline(WisperBotResolvedTheme colors) {
    final configuredWelcome = _state.widget?.welcomeMessage.trim();
    final welcome = configuredWelcome?.isNotEmpty == true
        ? configuredWelcome!
        : 'Hi there! How can we help?';
    const welcomeCount = 1;
    final typingCount = _state.agentTyping == null ? 0 : 1;
    return RefreshIndicator(
      color: colors.primary,
      onRefresh: _controller.refresh,
      child: Stack(
        children: <Widget>[
          ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            itemCount: welcomeCount + _state.messages.length + typingCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: EdgeInsets.only(bottom: colors.messageSpacing),
                  child: _WelcomeBubble(
                    body: welcome,
                    widgetConfig: _state.widget,
                    colors: colors,
                  ),
                );
              }
              final messageIndex = index - welcomeCount;
              if (messageIndex == _state.messages.length) {
                return _TypingIndicator(
                  typing: _state.agentTyping!,
                  colors: colors,
                );
              }
              final message = _state.messages[messageIndex];
              return Padding(
                padding: EdgeInsets.only(bottom: colors.messageSpacing),
                child: widget.messageBuilder?.call(context, message) ??
                    _MessageBubble(
                      message: message,
                      widgetConfig: _state.widget,
                      colors: colors,
                      onRetry:
                          message.status == WisperBotMessageStatus.failed &&
                                  message.error?.retryable == true
                              ? () => unawaited(
                                    _controller
                                        .retryMessage(message.localId)
                                        .catchError((_) => message),
                                  )
                              : null,
                      onRemove:
                          message.status == WisperBotMessageStatus.failed ||
                                  message.status ==
                                      WisperBotMessageStatus.unconfirmed
                              ? () => unawaited(
                                    _controller.removeMessage(message.localId),
                                  )
                              : null,
                      onRefresh:
                          message.status == WisperBotMessageStatus.unconfirmed
                              ? () => unawaited(
                                    _controller.refresh().catchError((_) {}),
                                  )
                              : null,
                    ),
              );
            },
          ),
          if (!_nearBottom)
            PositionedDirectional(
              end: 12,
              bottom: 12,
              child: FloatingActionButton.small(
                heroTag: null,
                tooltip: 'Jump to latest message',
                onPressed: _scrollToEnd,
                backgroundColor: colors.surface,
                foregroundColor: colors.onSurface,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(WisperBotResolvedTheme colors) {
    final custom = widget.composerBuilder;
    if (custom != null) return custom(context, _controller, _state);
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _HandoffAction(
              state: _state,
              colors: colors,
              onPressed: () => unawaited(
                _controller.requestHumanAgent().catchError((_) {}),
              ),
            ),
            _Composer(
              controller: _controller,
              colors: colors,
              mediaAdapter: widget.config.mediaAdapter,
              imagesEnabled: true,
              audioEnabled: true,
            ),
            BrandFooter(
              companyName: _state.widget?.footerCompanyName,
              colors: colors,
            ),
          ],
        ),
      ),
    );
  }

  bool _canCompose(WisperBotChatState state) =>
      state.phase == WisperBotChatPhase.ready ||
      state.phase == WisperBotChatPhase.reconnecting;

  @override
  void dispose() {
    _scrollController
      ..removeListener(_trackScrollPosition)
      ..dispose();
    unawaited(_subscription?.cancel());
    final client = _ownedClient;
    if (client != null) {
      unawaited(_controller.dispose().then((_) => client.close()));
    }
    super.dispose();
  }
}
