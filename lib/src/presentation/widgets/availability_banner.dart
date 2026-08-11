import 'package:flutter/material.dart';

import '../../domain/models/models.dart';
import '../theme/resolved_theme.dart';

/// Internal working-hours notice, independent of network connectivity.
class ChatAvailabilityBanner extends StatelessWidget {
  const ChatAvailabilityBanner({
    required this.state,
    required this.colors,
    super.key,
  });

  final WisperBotChatState state;
  final WisperBotResolvedTheme colors;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: colors.surfaceMuted,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          state.widget?.offlineMessage?.trim().isNotEmpty == true
              ? state.widget!.offlineMessage!
              : 'Support is currently away. You can still leave a message.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
