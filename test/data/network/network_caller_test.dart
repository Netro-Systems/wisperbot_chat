import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/network/api_endpoints.dart';
import 'package:wisperbot_chat/src/data/network/http_error_mapper.dart';
import 'package:wisperbot_chat/src/data/network/network_caller.dart';

void main() {
  test('GET resolves endpoint, query, token, and only allowed headers', () async {
    late http.BaseRequest recorded;
    final caller = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test/base/'),
      httpClient: _TestClient((request) async {
        recorded = request;
        return _response(<String, Object?>{});
      }),
    );

    await caller.get(
      ApiEndpoints.messages,
      token: 'visitor-token',
      query: const <String, String>{'key': 'widget', 'after': '4'},
      operation: WidgetOperation.poll,
    );

    expect(recorded.method, 'GET');
    expect(recorded.url.path, '/base/widget/v1/messages');
    expect(recorded.url.queryParameters, <String, String>{'key': 'widget', 'after': '4'});
    expect(recorded.headers['accept'], 'application/json');
    expect(recorded.headers['x-widget-token'], 'visitor-token');
    expect(recorded.headers.containsKey('content-type'), isFalse);
    expect(recorded.headers.keys.map((key) => key.toLowerCase()), isNot(contains('origin')));
    expect(recorded.headers.keys.map((key) => key.toLowerCase()), isNot(contains('referer')));
  });

  test('JSON POST applies content type and preserves the encoded body', () async {
    late http.Request recorded;
    final caller = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test'),
      httpClient: _TestClient((request) async {
        recorded = request as http.Request;
        return _response(<String, Object?>{});
      }),
    );

    await caller.postJson(
      ApiEndpoints.typing,
      body: '{"key":"widget","is_typing":true}',
      token: 'visitor-token',
      operation: WidgetOperation.typing,
    );

    expect(recorded.headers['content-type'], 'application/json');
    expect(jsonDecode(recorded.body), <String, Object?>{'key': 'widget', 'is_typing': true});
  });

  test('multipart upload owns fields, file, and transport headers', () async {
    late http.MultipartRequest recorded;
    late List<int> encodedBody;
    final caller = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test'),
      httpClient: _TestClient((request) async {
        recorded = request as http.MultipartRequest;
        encodedBody = await request.finalize().toBytes();
        return _response(<String, Object?>{});
      }),
    );

    await caller.upload(
      ApiEndpoints.messages,
      token: 'visitor-token',
      fields: const <String, String>{
        'key': 'widget',
        'type': 'image',
        'message': 'Screenshot',
      },
      fileField: 'attachment',
      fileBytes: const <int>[1, 2, 3],
      filename: 'photo.png',
      mimeType: 'image/png',
      operation: WidgetOperation.sendMedia,
    );

    expect(recorded.fields, <String, String>{
      'key': 'widget',
      'type': 'image',
      'message': 'Screenshot',
    });
    expect(recorded.files.single.field, 'attachment');
    expect(recorded.files.single.filename, 'photo.png');
    expect(recorded.files.single.contentType.toString(), 'image/png');
    expect(recorded.headers['accept'], 'application/json');
    expect(recorded.headers['x-widget-token'], 'visitor-token');
    expect(
      recorded.headers['content-type'],
      startsWith('multipart/form-data; boundary='),
    );
    final headerNames = recorded.headers.keys.map((key) => key.toLowerCase());
    expect(headerNames, isNot(contains('origin')));
    expect(headerNames, isNot(contains('referer')));
    final body = utf8.decode(encodedBody, allowMalformed: true);
    expect(body, contains('name="key"'));
    expect(body, contains('\r\n\r\nwidget\r\n'));
    expect(body, contains('name="type"'));
    expect(body, contains('\r\n\r\nimage\r\n'));
    expect(body, contains('name="message"'));
    expect(body, contains('\r\n\r\nScreenshot\r\n'));
    expect(body, contains('name="attachment"; filename="photo.png"'));
    expect(body.toLowerCase(), contains('content-type: image/png'));
  });

  test('maps HTTP, timeout, and connection failures to typed exceptions', () async {
    final rateLimited = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test'),
      httpClient: _TestClient(
        (_) async => _response(
          <String, Object?>{},
          status: 429,
          headers: const <String, String>{'retry-after': '7'},
        ),
      ),
    );
    await expectLater(
      rateLimited.get(
        ApiEndpoints.messages,
        token: 'token',
        operation: WidgetOperation.poll,
      ),
      throwsA(
        isA<WisperBotException>()
            .having(
              (error) => error.code,
              'code',
              WisperBotErrorCode.rateLimited,
            )
            .having(
              (error) => error.retryAfter,
              'retryAfter',
              const Duration(seconds: 7),
            ),
      ),
    );

    final timedOut = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test'),
      httpClient: _TestClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return _response(<String, Object?>{});
      }),
      requestTimeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      timedOut.get(
        ApiEndpoints.messages,
        token: 'token',
        operation: WidgetOperation.poll,
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.network,
        ),
      ),
    );

    final disconnected = NetworkCaller(
      baseUrl: Uri.parse('https://chat.example.test'),
      httpClient: _TestClient(
        (_) => throw http.ClientException('connection unavailable'),
      ),
    );
    await expectLater(
      disconnected.get(
        ApiEndpoints.messages,
        token: 'token',
        operation: WidgetOperation.poll,
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.network,
        ),
      ),
    );
  });
}

http.StreamedResponse _response(
  Object body, {
  int status = 200,
  Map<String, String> headers = const <String, String>{},
}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: <String, String>{
        'content-type': 'application/json',
        ...headers,
      },
    );

final class _TestClient extends http.BaseClient {
  _TestClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) => handler(request);
}
