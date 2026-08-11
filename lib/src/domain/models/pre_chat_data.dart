part of 'models.dart';

/// Visitor values submitted for backend-required pre-chat fields.
class WisperBotPreChatData {
  /// Creates pre-chat values. Required fields are validated by the controller.
  const WisperBotPreChatData({this.name, this.email});

  /// Visitor name.
  final String? name;

  /// Visitor email address.
  final String? email;
}
