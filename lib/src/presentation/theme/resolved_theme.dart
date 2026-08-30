import 'package:flutter/material.dart';

import '../../configuration/wisperbot_config.dart';
import '../../domain/models/models.dart';

const _brandPrimary = Color(0xFFFF762E);
const _brandBackground = Color(0xFFF7F8FA);
const _brandSurface = Colors.white;
const _brandSurfaceMuted = Color(0xFFF1F3F6);
const _brandOnSurface = Color(0xFF1F2430);

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
    required bool useApiColors,
  }) {
    final serverPrimary = useApiColors ? _parseHex(server?.primaryColorHex) : null;
    final requestedBrightness = override?.brightness;
    final colorScheme = requestedBrightness == null
        ? hostTheme.colorScheme
        : ColorScheme.fromSeed(
            seedColor: override?.primaryColor ?? serverPrimary ?? _brandPrimary,
            brightness: requestedBrightness,
          );
    final primary = override?.primaryColor ?? serverPrimary ?? _brandPrimary;
    final isDark = colorScheme.brightness == Brightness.dark;
    final surface = override?.surfaceColor ?? (isDark ? colorScheme.surface : _brandSurface);
    final background = override?.backgroundColor ??
        (isDark
            ? Color.alphaBlend(
                colorScheme.onSurface.withValues(alpha: 0.05),
                surface,
              )
            : _brandBackground);
    final visitorBubble = override?.visitorBubbleColor ?? primary;
    final agentBubble = override?.agentBubbleColor ?? surface;
    final onSurface = isDark ? colorScheme.onSurface : _brandOnSurface;
    return WisperBotResolvedTheme(
      primary: primary,
      onPrimary: _contrasting(primary),
      background: background,
      surface: surface,
      surfaceMuted: isDark ? colorScheme.surfaceContainerHigh : _brandSurfaceMuted,
      visitorBubble: visitorBubble,
      onVisitorBubble: override?.onVisitorBubbleColor ?? _contrasting(visitorBubble),
      agentBubble: agentBubble,
      onAgentBubble: override?.onAgentBubbleColor ?? onSurface,
      error: override?.errorColor ?? colorScheme.error,
      onSurface: onSurface,
      onSurfaceMuted:
          isDark ? colorScheme.onSurface.withValues(alpha: 0.68) : const Color(0xFF687386),
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
