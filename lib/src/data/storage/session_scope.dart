import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../configuration/wisperbot_config.dart';
import '../../domain/entities/wisperbot_user.dart';
import '../../domain/errors/wisperbot_exception.dart';

const int wisperBotSessionSchemaVersion = 2;
const int _wisperBotSessionNamespaceVersion = 1;

Uri validateAndCanonicalizeBaseUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'apiBaseUrl must be an absolute HTTP or HTTPS URL.',
      retryable: false,
    );
  }
  if (uri.scheme != 'https' && (!kDebugMode || uri.scheme != 'http')) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'apiBaseUrl must use HTTPS in release builds.',
      retryable: false,
    );
  }
  if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'apiBaseUrl cannot include credentials, a query, or a fragment.',
      retryable: false,
    );
  }

  var path = uri.path;
  while (path.endsWith('/') && path.length > 1) {
    path = path.substring(0, path.length - 1);
  }
  final effectivePort = uri.hasPort &&
          !((uri.scheme == 'https' && uri.port == 443) ||
              (uri.scheme == 'http' && uri.port == 80))
      ? uri.port
      : null;
  return Uri(
    scheme: uri.scheme.toLowerCase(),
    host: uri.host.toLowerCase(),
    port: effectivePort,
    path: path == '/' ? '' : path,
  );
}

void validateWisperBotConfig(WisperBotConfig config) {
  if (config.widgetKey.trim().isEmpty) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'widgetKey cannot be empty.',
      retryable: false,
    );
  }
  validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
}

void validateWisperBotUser(WisperBotUser? user) {
  if (user == null) return;
  final userId = user.userId;
  if (userId != null && (userId.isEmpty || userId.trim() != userId)) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'userId must be non-empty with no surrounding whitespace.',
      retryable: false,
    );
  }
  final externalId = user.externalId;
  if (userId != null && externalId != null && userId != externalId) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'userId and externalId must match when both are provided.',
      retryable: false,
    );
  }
  if ((userId?.length ?? 0) > 190 ||
      (user.email?.length ?? 0) > 190 ||
      (user.name?.length ?? 0) > 120 ||
      (user.avatarUrl?.toString().length ?? 0) > 512 ||
      (user.signature?.length ?? 0) > 128) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'User identity exceeds the supported field limits.',
      retryable: false,
    );
  }
  if (user.signature != null && userId == null) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'A signature requires a userId.',
      retryable: false,
    );
  }
  if (user.email != null &&
      !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(user.email!)) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'email is not valid.',
      retryable: false,
    );
  }
  final avatar = user.avatarUrl;
  if (avatar != null &&
      (!avatar.isAbsolute ||
          (kReleaseMode && avatar.scheme.toLowerCase() != 'https'))) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'avatarUrl must be an absolute HTTPS URL in release builds.',
      retryable: false,
    );
  }
}

String createEphemeralScopeId() {
  final random = Random.secure();
  final values = List<int>.generate(24, (_) => random.nextInt(256));
  return base64UrlEncode(values).replaceAll('=', '');
}

String sessionNamespace({
  required WisperBotConfig config,
  required WisperBotUser? user,
  String? unsignedEphemeralScope,
}) {
  final canonical = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
  final stableUserId = user?.userId;
  final identityScope =
      stableUserId == null ? 'anonymous' : 'user:$stableUserId';
  final material = <String>[
    canonical.toString(),
    config.widgetKey,
    identityScope,
    'v$_wisperBotSessionNamespaceVersion',
  ].join('\u0000');
  return 'wisperbot_chat_${sha256.convert(utf8.encode(material))}';
}

/// Returns the pre-0.2.2 account namespace so its schema-v1 credentials can be
/// moved once into the canonical user-ID scope. Email-only/profile-only scopes
/// are deliberately excluded because those fields no longer define identity.
String? legacyAccountSessionNamespace({
  required WisperBotConfig config,
  required WisperBotUser? user,
}) {
  final stableUserId = user?.userId;
  if (stableUserId == null) return null;
  final canonical = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
  final identityScope = user?.signature == null
      ? 'unsigned-stable:$stableUserId'
      : 'signed:$stableUserId\u0000${user!.signature}';
  final material = <String>[
    canonical.toString(),
    config.widgetKey,
    identityScope,
    'v1',
  ].join('\u0000');
  return 'wisperbot_chat_${sha256.convert(utf8.encode(material))}';
}

bool isAnonymousEquivalentUser(WisperBotUser? user) => user?.userId == null;

String? unsignedStableIdentityValue(WisperBotUser? user) {
  if (user == null || user.signature != null) return null;
  return user.userId;
}

/// Returns a privacy-safe hash of the durable identity. Mutable profile fields
/// intentionally do not invalidate the visitor token.
String wisperBotUserProfileFingerprint(WisperBotUser? user) {
  final profile = <String, Object?>{
    'user_id': user?.userId,
  };
  return sha256.convert(utf8.encode(jsonEncode(profile))).toString();
}

String presentationScopeKey(
  WisperBotConfig config, {
  WisperBotUser? user,
}) {
  final canonical = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
  final identity = user?.userId == null ? 'anonymous' : 'user:${user!.userId}';
  return sha256
      .convert(
        utf8.encode(
          <String>[canonical.toString(), config.widgetKey, identity].join(
            '\u0000',
          ),
        ),
      )
      .toString();
}
