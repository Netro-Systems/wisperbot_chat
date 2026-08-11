import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/resolved_theme.dart';

/// Internal terminal error presentation with an optional safe retry action.
class ChatErrorState extends StatelessWidget {
  const ChatErrorState({
    required this.state,
    required this.colors,
    required this.onRetry,
    super.key,
  });

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.error_outline, color: colors.error, size: 40),
                  const SizedBox(height: 16),
                  Text(
                    state.error?.message ?? 'Chat is unavailable.',
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...<Widget>[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
