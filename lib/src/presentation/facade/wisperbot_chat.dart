import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/wisperbot_runtime.dart';
import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/events/chat_event.dart';
import '../screen/chat_screen.dart';
import '../view/chat_view.dart';

/// Static helpers for modal chat presentation and identity-scoped reset.
abstract final class WisperBotChat {
  static final Map<String, Future<WisperBotChatResult?>> _activePresentations =
      <String, Future<WisperBotChatResult?>>{};
  static final Map<String, WisperBotChatController> _ownedControllers =
      <String, WisperBotChatController>{};

  /// Opens at most one chat presentation for the configuration scope.
  ///
  /// Uses [config.presentation] unless [presentation] overrides it. A supplied
  /// [controller] remains owned by the caller. Throws [WisperBotException]
  /// when configuration is invalid or the controller belongs to another
  /// identity/widget scope.
  static Future<WisperBotChatResult?> open(
    BuildContext context, {
    required WisperBotConfig config,
    WisperBotChatController? controller,
    WisperBotPresentation? presentation,
  }) {
    validateWisperBotRuntimeConfig(config);
    final scope = wisperBotPresentationScope(config);
    final active = _activePresentations[scope];
    if (active != null) return active;

    if (controller != null &&
        wisperBotPresentationScope(controller.config) != scope) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message:
            'The supplied controller does not match the chat configuration.',
        retryable: false,
      );
    }

    final completer = Completer<WisperBotChatResult?>();
    _activePresentations[scope] = completer.future;
    unawaited(
      _openPresentation(
        context,
        scope: scope,
        config: config,
        suppliedController: controller,
        presentation: presentation ?? config.presentation,
      ).then(completer.complete, onError: completer.completeError).whenComplete(
            () => _activePresentations.remove(scope),
          ),
    );
    return completer.future;
  }

  static Future<WisperBotChatResult?> _openPresentation(
    BuildContext context, {
    required String scope,
    required WisperBotConfig config,
    required WisperBotChatController? suppliedController,
    required WisperBotPresentation presentation,
  }) async {
    WisperBotClient? ownedClient;
    final controller = suppliedController ??
        (() {
          final client = WisperBotClient(config: config);
          ownedClient = client;
          return WisperBotChatController(client: client);
        })();
    if (ownedClient != null) _ownedControllers[scope] = controller;

    try {
      switch (presentation) {
        case WisperBotPresentation.fullScreen:
          await Navigator.of(context).push<WisperBotChatResult>(
            MaterialPageRoute<WisperBotChatResult>(
              builder: (_) => WisperBotChatScreen(
                config: config,
                controller: controller,
              ),
            ),
          );
          break;
        case WisperBotPresentation.bottomSheet:
          controller.handlePresentationOpened();
          await showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: FractionallySizedBox(
                key: const ValueKey<String>('wisperbot-bottom-sheet'),
                heightFactor: 0.96,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  child: Material(
                    child: WisperBotChatView(
                      config: config,
                      controller: controller,
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(
            WisperBotChatCloseReason.userClosed,
          );
          break;
        case WisperBotPresentation.dialog:
          controller.handlePresentationOpened();
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 420,
                  maxHeight: 720,
                ),
                child: SizedBox(
                  width: 420,
                  height: MediaQuery.sizeOf(dialogContext).height * 0.82,
                  child: WisperBotChatView(
                    config: config,
                    controller: controller,
                    onClose: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          );
          controller.handlePresentationClosed(
            WisperBotChatCloseReason.userClosed,
          );
          break;
      }
      return const WisperBotChatResult(
        reason: WisperBotChatCloseReason.userClosed,
      );
    } finally {
      if (ownedClient != null) {
        _ownedControllers.remove(scope);
        await controller.dispose();
        await ownedClient!.close();
      }
    }
  }

  /// Deletes credentials for [config] and resets any facade-owned controller.
  ///
  /// Throws [WisperBotException] when configuration or secure storage fails.
  static Future<void> resetSession({required WisperBotConfig config}) async {
    validateWisperBotRuntimeConfig(config);
    final scope = wisperBotPresentationScope(config);
    final active = _ownedControllers[scope];
    if (active != null) {
      await active.resetSession();
      return;
    }

    await resetWisperBotStoredSession(config);
  }
}
