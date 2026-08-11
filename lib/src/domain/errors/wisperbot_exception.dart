/// Stable categories exposed for failures produced by the SDK.
enum WisperBotErrorCode {
  configuration,
  unauthorized,
  sessionExpired,
  forbidden,
  rateLimited,
  validation,
  attachmentRejected,
  edgeRejected,
  network,
  server,
  unsupported,
  unknown,
}

/// A safe, typed failure that never includes credentials or raw response data.
class WisperBotException implements Exception {
  /// Creates a safe failure suitable for application state and diagnostics.
  const WisperBotException({
    required this.code,
    required this.message,
    required this.retryable,
    this.httpStatus,
    this.fieldErrors = const <String, List<String>>{},
    this.retryAfter,
  });

  /// Stable machine-readable failure category.
  final WisperBotErrorCode code;

  /// Safe user-facing description without raw response data.
  final String message;

  /// Whether repeating the associated safe operation may succeed.
  final bool retryable;

  /// HTTP status when the failure came from a response.
  final int? httpStatus;

  /// Safe validation messages grouped by request field.
  final Map<String, List<String>> fieldErrors;

  /// Server-requested delay before another safe operation.
  final Duration? retryAfter;

  @override
  String toString() => 'WisperBotException(code: $code, message: $message, '
      'retryable: $retryable, httpStatus: $httpStatus)';
}
