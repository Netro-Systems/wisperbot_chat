import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

import '../domain/errors/wisperbot_exception.dart';

/// Development-only, privacy-safe diagnostics for image and audio uploads.
///
/// These logs intentionally exclude visitor credentials, widget keys, host
/// URLs, filenames, message captions, attachment URLs, and file bytes.
final class WisperBotDebugUploadLogger {
  WisperBotDebugUploadLogger._();

  static final Logger _logger = Logger(
    printer: SimplePrinter(colors: false, printTime: true),
  );

  static void selectionStarted() => _debug('image_upload: selection started');

  static void selectionCancelled() => _debug('image_upload: selection cancelled');

  static void selectionReady({
    required int sizeBytes,
    required String mimeType,
  }) =>
      _debug(
        'image_upload: selection ready '
        '(sizeBytes=$sizeBytes, mimeType=$mimeType)',
      );

  static void selectionFailed(Object error) => _debug(
        'image_upload: selection failed (${_safeError(error)})',
      );

  static void sendRequested({
    required int sizeBytes,
    required String mimeType,
  }) =>
      _debug(
        'image_upload: send requested '
        '(sizeBytes=$sizeBytes, mimeType=$mimeType)',
      );

  static void multipartBuilt({
    required String operation,
    required int sizeBytes,
    required String mimeType,
  }) =>
      _debug(
        '$operation: multipart built '
        '(field=attachment, sizeBytes=$sizeBytes, mimeType=$mimeType)',
      );

  static void requestDispatched(String operation) => _debug('$operation: HTTP request dispatched');

  static void responseReceived(
    String operation,
    int statusCode,
    String? contentType,
  ) =>
      _debug(
        '$operation: HTTP response received '
        '(status=$statusCode, contentType=${_safeContentType(contentType)})',
      );

  static void sendConfirmed() => _debug('image_upload: send confirmed');

  static void failed(String operation, WisperBotException error) => _debug(
        '$operation: failed '
        '(code=${error.code.name}, status=${error.httpStatus})',
      );

  static void unexpectedFailure(String operation, Object error) =>
      _debug('$operation: failed (${_safeError(error)})');

  static String _safeError(Object error) {
    if (error is PlatformException) {
      final code = error.code.trim();
      final message = error.message?.trim();
      return [
        'error=PlatformException',
        if (code.isNotEmpty) 'code=$code',
        if (message != null && message.isNotEmpty) 'message=$message',
      ].join(', ');
    }
    return 'error=${error.runtimeType}';
  }

  static String _safeContentType(String? value) {
    final type = value?.split(';').first.trim().toLowerCase();
    return type == null || type.isEmpty ? 'unknown' : type;
  }

  static void _debug(String message) {
    if (kDebugMode) _logger.d(message);
  }
}
