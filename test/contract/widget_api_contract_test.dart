import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/datasources/widget_remote_data_source.dart';
import 'package:wisperbot_chat/src/data/network/network_caller.dart';

import '../support/support.dart';

part 'widget_api_request_contract_tests.dart';
part 'widget_api_response_contract_tests.dart';

void main() {
  _registerRequestContractTests();
  _registerResponseContractTests();
}

HttpWidgetRemoteDataSource _remoteDataSource({
  required Uri baseUrl,
  required http.Client httpClient,
  Duration requestTimeout = const Duration(seconds: 30),
}) =>
    HttpWidgetRemoteDataSource(
      networkCaller: NetworkCaller(
        baseUrl: baseUrl,
        httpClient: httpClient,
        requestTimeout: requestTimeout,
      ),
    );

void _expectNoInventedHeaders(http.BaseRequest request) {
  final names = request.headers.keys.map((key) => key.toLowerCase()).toSet();
  expect(names, isNot(contains('x-wisperbot-sdk')));
  expect(names, isNot(contains('x-wisperbot-filename-b64')));
  expect(names, isNot(contains('x-wisperbot-caption-b64')));
  expect(names, isNot(contains('origin')));
  expect(names, isNot(contains('referer')));
}

http.StreamedResponse _jsonResponse(
  Object body, {
  int status = 200,
}) =>
    http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
