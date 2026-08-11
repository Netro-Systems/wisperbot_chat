import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/network/http_error_mapper.dart';

void main() {
  test('maps endpoint-aware status codes and retry-after', () {
    final missingWidget = mapWidgetHttpError(
      http.Response('', 404),
      operation: WidgetOperation.session,
    );
    final expiredSession = mapWidgetHttpError(
      http.Response('', 404),
      operation: WidgetOperation.poll,
    );
    final throttled = mapWidgetHttpError(
      http.Response('', 429, headers: <String, String>{'retry-after': '9'}),
      operation: WidgetOperation.poll,
    );

    expect(missingWidget.code, WisperBotErrorCode.configuration);
    expect(missingWidget.retryable, isFalse);
    expect(expiredSession.code, WisperBotErrorCode.sessionExpired);
    expect(expiredSession.retryable, isTrue);
    expect(throttled.retryAfter, const Duration(seconds: 9));
  });

  test('retains safe validation details for presentation', () {
    final error = mapWidgetHttpError(
      http.Response(
        jsonEncode(<String, Object>{
          'message': 'sensitive server detail',
          'errors': <String, Object>{
            'email': <String>['Invalid email'],
          },
        }),
        422,
      ),
      operation: WidgetOperation.sendText,
    );

    expect(error.code, WisperBotErrorCode.validation);
    expect(error.fieldErrors['email'], <String>['Invalid email']);
    expect(error.message, 'sensitive server detail');
  });

  test('maps an infrastructure payload limit to attachment rejection', () {
    final error = mapWidgetHttpError(
      http.Response('', 413),
      operation: WidgetOperation.sendMedia,
    );

    expect(error.code, WisperBotErrorCode.attachmentRejected);
    expect(error.httpStatus, 413);
  });

  test('distinguishes an edge security rejection from validation', () {
    final error = mapWidgetHttpError(
      http.Response(
        '<html>Not acceptable</html>',
        406,
        headers: <String, String>{'content-type': 'text/html'},
      ),
      operation: WidgetOperation.sendMedia,
    );

    expect(error.code, WisperBotErrorCode.edgeRejected);
    expect(error.httpStatus, 406);
    expect(error.retryable, isFalse);
    expect(error.message, contains('security layer'));
  });

  test('does not classify a JSON 406 response as an edge HTML rejection', () {
    final error = mapWidgetHttpError(
      http.Response(
        jsonEncode(<String, Object?>{'message': 'Not acceptable'}),
        406,
        headers: <String, String>{'content-type': 'application/json'},
      ),
      operation: WidgetOperation.sendMedia,
    );

    expect(error.code, WisperBotErrorCode.unknown);
    expect(error.httpStatus, 406);
  });

  test('maps the complete media HTTP failure matrix', () {
    WisperBotException mediaError(
      int status, {
      Object body = const <String, Object?>{},
      Map<String, String> headers = const <String, String>{},
    }) =>
        mapWidgetHttpError(
          http.Response(jsonEncode(body), status, headers: headers),
          operation: WidgetOperation.sendMedia,
        );

    expect(mediaError(401).code, WisperBotErrorCode.sessionExpired);
    expect(mediaError(413).code, WisperBotErrorCode.attachmentRejected);
    final validation = mediaError(
      422,
      body: <String, Object?>{
        'message': 'Validation failed.',
        'errors': <String, Object?>{
          'attachment': <String>['Choose a JPG, PNG, or WebP image.'],
        },
      },
    );
    expect(validation.code, WisperBotErrorCode.attachmentRejected);
    expect(validation.message, 'Choose a JPG, PNG, or WebP image.');
    final throttled = mediaError(
      429,
      headers: <String, String>{'retry-after': '12'},
    );
    expect(throttled.code, WisperBotErrorCode.rateLimited);
    expect(throttled.retryAfter, const Duration(seconds: 12));
    expect(mediaError(503).code, WisperBotErrorCode.server);
  });
}
