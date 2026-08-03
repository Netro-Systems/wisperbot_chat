import 'package:flutter/material.dart';

import '../domain/config.dart';
import '../domain/models.dart';

class WisperBotResolvedTheme {
  WisperBotResolvedTheme({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.visitorBubble,
    required this.onVisitorBubble,
    required this.agentBubble,
    required this.onAgentBubble,
    required this.error,
    required this.onSurface,
    required this.onSurfaceMuted,
    required this.outline,
    required this.borderRadius,
    required this.messageSpacing,
    required this.launcherSize,
  });

  factory WisperBotResolvedTheme.resolve({
    required ThemeData hostTheme,
    required WisperBotThemeData? override,
    required WisperBotWidgetConfig? server,
  }) {
    final serverPrimary = _parseHex(server?.primaryColorHex);
    final requestedBrightness = override?.brightness;
    final colorScheme = requestedBrightness == null
        ? hostTheme.colorScheme
        : ColorScheme.fromSeed(
            seedColor: override?.primaryColor ??
                serverPrimary ??
                hostTheme.colorScheme.primary,
            brightness: requestedBrightness,
          );
    final primary =
        override?.primaryColor ?? serverPrimary ?? colorScheme.primary;
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = override?.surfaceColor ?? colorScheme.surface;
    final background = override?.backgroundColor ??
        Color.alphaBlend(
          colorScheme.onSurface.withValues(alpha: isDark ? 0.05 : 0.025),
          surface,
        );
    final visitorBubble = override?.visitorBubbleColor ?? primary;
    final agentBubble = override?.agentBubbleColor ?? surface;
    return WisperBotResolvedTheme(
      primary: primary,
      onPrimary: _contrasting(primary),
      background: background,
      surface: surface,
      surfaceMuted: colorScheme.surfaceContainerHigh,
      visitorBubble: visitorBubble,
      onVisitorBubble:
          override?.onVisitorBubbleColor ?? _contrasting(visitorBubble),
      agentBubble: agentBubble,
      onAgentBubble: override?.onAgentBubbleColor ?? colorScheme.onSurface,
      error: override?.errorColor ?? colorScheme.error,
      onSurface: colorScheme.onSurface,
      onSurfaceMuted: isDark
          ? colorScheme.onSurface.withValues(alpha: 0.68)
          : const Color(0xFF687386),
      outline: isDark ? colorScheme.outlineVariant : const Color(0xFFECEEF2),
      borderRadius: override?.borderRadius?.clamp(4, 32).toDouble() ?? 16,
      messageSpacing: override?.messageSpacing?.clamp(2, 24).toDouble() ?? 8,
      launcherSize: override?.launcherSize?.clamp(48, 80).toDouble() ?? 56,
    );
  }

  final Color primary;
  final Color onPrimary;
  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color visitorBubble;
  final Color onVisitorBubble;
  final Color agentBubble;
  final Color onAgentBubble;
  final Color error;
  final Color onSurface;
  final Color onSurfaceMuted;
  final Color outline;
  final double borderRadius;
  final double messageSpacing;
  final double launcherSize;
}

Color _contrasting(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;

Color? _parseHex(String? value) {
  if (value == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
    return null;
  }
  return Color(int.parse(value.substring(1), radix: 16) | 0xFF000000);
}
