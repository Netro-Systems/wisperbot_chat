part of 'models.dart';

/// Server-configured launcher alignment.
enum WisperBotLauncherPosition { bottomRight, bottomLeft, unknown }

/// Pre-chat fields currently understood by the SDK.
enum WisperBotPreChatField { name, email, unknown }

/// Public team-member presentation data returned by widget configuration.
class WisperBotTeamMember {
  /// Creates immutable team-member presentation data.
  const WisperBotTeamMember({required this.name, this.avatarUrl});

  /// Display name.
  final String name;

  /// Optional avatar URL.
  final Uri? avatarUrl;
}

/// Immutable public widget configuration returned by the session API.
///
/// Collection fields are defensively copied and cannot be mutated by callers.
class WisperBotWidgetConfig {
  /// Creates parsed widget configuration.
  WisperBotWidgetConfig({
    required this.title,
    required this.subtitle,
    required this.welcomeMessage,
    required this.agentName,
    required this.primaryColorHex,
    required this.launcherPosition,
    required this.footerCompanyName,
    required List<WisperBotTeamMember> teamMembers,
    required this.aiEnabled,
    required this.requiresPreChat,
    required List<WisperBotPreChatField> preChatFields,
    this.avatarUrl,
    this.launcherText,
    this.launcherLogoUrl,
    this.offlineMessage,
  })  : teamMembers = List<WisperBotTeamMember>.unmodifiable(teamMembers),
        preChatFields = List<WisperBotPreChatField>.unmodifiable(preChatFields);

  /// Header title.
  final String title;

  /// Header subtitle.
  final String subtitle;

  /// Introductory welcome text; this is not conversation history.
  final String welcomeMessage;

  /// Generic support name configured for the widget.
  final String agentName;

  /// Optional header avatar URL.
  final Uri? avatarUrl;

  /// Server primary color in hexadecimal notation.
  final String primaryColorHex;

  /// Preferred floating-launcher alignment.
  final WisperBotLauncherPosition launcherPosition;

  /// Optional launcher label.
  final String? launcherText;

  /// Optional launcher image URL.
  final Uri? launcherLogoUrl;

  /// Footer company label.
  final String footerCompanyName;

  /// Team members shown by supported presentations.
  final List<WisperBotTeamMember> teamMembers;

  /// Whether the widget has active AI support.
  final bool aiEnabled;

  /// Whether the backend requires pre-chat submission.
  final bool requiresPreChat;

  /// Required pre-chat fields.
  final List<WisperBotPreChatField> preChatFields;

  /// Server message shown outside working hours.
  final String? offlineMessage;
}
