import 'package:flutter/foundation.dart';

/// Stable categories exposed for failures produced by the SDK.
enum WisperBotErrorCode {
  configuration,
  unauthorized,
  sessionExpired,
  forbidden,
  rateLimited,
  validation,
  attachmentRejected,
  network,
  server,
  unsupported,
  unknown,
}

/// A safe, typed failure that never includes credentials or raw response data.
@immutable
class WisperBotException implements Exception {
  const WisperBotException({
    required this.code,
    required this.message,
    required this.retryable,
    this.httpStatus,
    this.fieldErrors = const <String, List<String>>{},
    this.retryAfter,
  });

  final WisperBotErrorCode code;
  final String message;
  final bool retryable;
  final int? httpStatus;
  final Map<String, List<String>> fieldErrors;
  final Duration? retryAfter;

  @override
  String toString() => 'WisperBotException(code: $code, message: $message, '
      'retryable: $retryable, httpStatus: $httpStatus)';
}
