import 'package:flutter/material.dart';

import '../theme/resolved_theme.dart';

/// Internal reconnecting status shown above the conversation.
class ChatConnectionBanner extends StatelessWidget {
  const ChatConnectionBanner({required this.colors, super.key});

  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          color: colors.surfaceMuted,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Text(
            'Reconnecting. New messages may not be confirmed yet.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}
