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

  test('retains bounded validation fields but not arbitrary response values',
      () {
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
    expect(error.toString(), isNot(contains('sensitive server detail')));
  });
}
