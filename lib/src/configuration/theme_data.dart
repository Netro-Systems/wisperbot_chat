part of 'wisperbot_config.dart';

/// Optional presentation overrides for the prebuilt WisperBot UI.
///
/// Null values fall through to server branding and then package/host defaults.
@immutable
class WisperBotThemeData {
  /// Creates a set of optional theme overrides.
  const WisperBotThemeData({
    this.primaryColor,
    this.backgroundColor,
    this.surfaceColor,
    this.visitorBubbleColor,
    this.agentBubbleColor,
    this.onVisitorBubbleColor,
    this.onAgentBubbleColor,
    this.errorColor,
    this.borderRadius,
    this.messageSpacing,
    this.launcherSize,
    this.brightness,
  });

  /// Primary action and launcher color.
  final Color? primaryColor;

  /// Conversation background color.
  final Color? backgroundColor;

  /// Header and composer surface color.
  final Color? surfaceColor;

  /// Visitor message bubble color.
  final Color? visitorBubbleColor;

  /// Agent message bubble color.
  final Color? agentBubbleColor;

  /// Foreground color for visitor bubbles.
  final Color? onVisitorBubbleColor;

  /// Foreground color for agent bubbles.
  final Color? onAgentBubbleColor;

  /// Error-state color.
  final Color? errorColor;

  /// Shared bubble corner radius.
  final double? borderRadius;

  /// Vertical spacing between messages.
  final double? messageSpacing;

  /// Diameter of the floating launcher.
  final double? launcherSize;

  /// Optional brightness override.
  final Brightness? brightness;
}
