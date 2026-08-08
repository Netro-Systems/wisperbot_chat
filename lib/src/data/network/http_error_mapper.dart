import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/errors/wisperbot_exception.dart';

/// Widget operation categories whose HTTP semantics differ by endpoint.
enum WidgetOperation { session, poll, sendText, sendMedia, typing, handoff }

/// Converts HTTP failures into safe, operation-aware public exceptions.
WisperBotException mapWidgetHttpError(
  http.Response response, {
  required WidgetOperation operation,
}) {
  final status = response.statusCode;
  final sessionRequest = operation == WidgetOperation.session;
  final fieldErrors = _safeFieldErrors(response);
  final retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
  return switch (status) {
    400 => WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'The WisperBot request configuration is invalid.',
        retryable: false,
        httpStatus: status,
        fieldErrors: fieldErrors,
      ),
    401 => WisperBotException(
        code: WisperBotErrorCode.sessionExpired,
        message: 'The chat session expired.',
        retryable: !sessionRequest,
        httpStatus: status,
      ),
    403 => WisperBotException(
        code: WisperBotErrorCode.forbidden,
        message: 'This widget is not allowed for the current application.',
        retryable: false,
        httpStatus: status,
      ),
    404 => WisperBotException(
        code: sessionRequest
            ? WisperBotErrorCode.configuration
            : WisperBotErrorCode.sessionExpired,
        message: sessionRequest
            ? 'The widget is missing or disabled.'
            : 'The chat session is no longer available.',
        retryable: !sessionRequest,
        httpStatus: status,
      ),
    422 => WisperBotException(
        code: operation == WidgetOperation.sendMedia
            ? WisperBotErrorCode.attachmentRejected
            : WisperBotErrorCode.validation,
        message: operation == WidgetOperation.sendMedia
            ? 'The attachment was rejected by WisperBot.'
            : 'The request could not be validated.',
        retryable: false,
        httpStatus: status,
        fieldErrors: fieldErrors,
      ),
    429 => WisperBotException(
        code: WisperBotErrorCode.rateLimited,
        message: 'Too many requests. Try again shortly.',
        retryable: true,
        httpStatus: status,
        retryAfter: retryAfterSeconds == null
            ? null
            : Duration(seconds: retryAfterSeconds),
      ),
    >= 500 => WisperBotException(
        code: WisperBotErrorCode.server,
        message: 'WisperBot is temporarily unavailable.',
        retryable: true,
        httpStatus: status,
      ),
    _ => WisperBotException(
        code: WisperBotErrorCode.unknown,
        message: 'The request could not be completed.',
        retryable: false,
        httpStatus: status,
      ),
  };
}

Map<String, List<String>> _safeFieldErrors(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['errors'] is! Map<String, dynamic>) {
      return const <String, List<String>>{};
    }
    final errors = decoded['errors'] as Map<String, dynamic>;
    return <String, List<String>>{
      for (final entry in errors.entries)
        entry.key: switch (entry.value) {
          List<dynamic> values => values.whereType<String>().take(5).toList(),
          String value => <String>[value],
          _ => const <String>[],
        },
    };
  } on Object {
    return const <String, List<String>>{};
  }
}
