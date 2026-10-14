import 'package:flutter/foundation.dart';

/// Optional visitor identity and profile supplied to a WisperBot runtime.
///
/// [userId] is the host application's stable user identifier. [signature] is
/// optional and is needed only when advanced identity verification is enabled
/// for the WisperBot widget. Every field is redacted from [toString].
@immutable
class WisperBotUser {
  /// Creates an optional visitor identity and profile.
  const WisperBotUser({
    String? userId,
    this.externalId,
    this.name,
    this.email,
    this.avatarUrl,
    this.signature,
    this.customFields,
  }) : userId = userId ?? externalId;

  /// Stable host-application identifier for the logged-in visitor.
  final String? userId;

  /// Legacy alias for [userId]. New integrations should use [userId].
  @Deprecated('Use userId instead.')
  final String? externalId;

  /// Visitor display name.
  final String? name;

  /// Visitor email address.
  final String? email;

  /// Visitor avatar URL.
  final Uri? avatarUrl;

  /// Optional server-generated HMAC identity signature.
  final String? signature;

  /// Optional custom metadata and additional fields.
  final Map<String, dynamic>? customFields;

  @override
  String toString() =>
      'WisperBotUser(userId: [redacted], externalId: [redacted], name: [redacted], '
      'email: [redacted], avatarUrl: [redacted], signature: [redacted], '
      'customFields: [redacted])';
}
