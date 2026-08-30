import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../configuration/wisperbot_config.dart';
import '../../domain/errors/wisperbot_exception.dart';

const int wisperBotSessionSchemaVersion = 1;

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
          !((uri.scheme == 'https' && uri.port == 443) || (uri.scheme == 'http' && uri.port == 80))
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
  _validateUser(config.user);
  if (config.polling.visibleInterval <= Duration.zero ||
      config.polling.idleInterval <= Duration.zero ||
      config.polling.failureMaxInterval <= Duration.zero) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'Polling intervals must be positive.',
      retryable: false,
    );
  }
}

void _validateUser(WisperBotUser? user) {
  if (user == null) return;
  final externalId = user.externalId;
  if (externalId != null && (externalId.isEmpty || externalId.trim() != externalId)) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'externalId must be non-empty with no surrounding whitespace.',
      retryable: false,
    );
  }
  if ((externalId?.length ?? 0) > 190 ||
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
  if (user.signature != null && externalId == null && user.email == null) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'A signature requires an externalId or email.',
      retryable: false,
    );
  }
  if (user.email != null && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(user.email!)) {
    throw const WisperBotException(
      code: WisperBotErrorCode.configuration,
      message: 'email is not valid.',
      retryable: false,
    );
  }
  final avatar = user.avatarUrl;
  if (avatar != null &&
      (!avatar.isAbsolute || (kReleaseMode && avatar.scheme.toLowerCase() != 'https'))) {
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
  final anonymous = isAnonymousEquivalentUser(user);
  final signature = user?.signature;
  final signedValue = user?.externalId ?? user?.email;
  final unsignedStableValue = unsignedStableIdentityValue(user);
  final identityScope = signature != null && signedValue != null
      ? 'signed:$signedValue\u0000$signature'
      : anonymous
          ? 'anonymous'
          : unsignedStableValue != null
              ? 'unsigned-stable:$unsignedStableValue'
              : 'unsigned:${unsignedEphemeralScope ?? createEphemeralScopeId()}';
  final material = <String>[
    canonical.toString(),
    config.widgetKey,
    identityScope,
    'v$wisperBotSessionSchemaVersion',
  ].join('\u0000');
  return 'wisperbot_chat_${sha256.convert(utf8.encode(material))}';
}

bool isAnonymousEquivalentUser(WisperBotUser? user) =>
    user == null ||
    (user.externalId == null &&
        user.name == null &&
        user.email == null &&
        user.avatarUrl == null &&
        user.signature == null);

String? unsignedStableIdentityValue(WisperBotUser? user) {
  if (user == null || user.signature != null) return null;
  return user.externalId ?? user.email;
}

String presentationScopeKey(WisperBotConfig config) {
  final canonical = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
  final user = config.user;
  final identity = user?.signature != null
      ? '${user?.externalId ?? user?.email}\u0000${user?.signature}'
      : user == null
          ? 'anonymous'
          : 'unsigned:${user.externalId ?? ''}:${user.email ?? ''}';
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
