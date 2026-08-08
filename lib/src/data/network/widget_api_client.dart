import 'dart:async';

import 'package:http/http.dart' as http;

import '../../configuration/wisperbot_config.dart';
import '../../domain/contracts/session_store.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';
import 'http_error_mapper.dart';
import 'request_encoder.dart';
import 'response_decoder.dart';
import 'widget_endpoints.dart';
import 'widget_results.dart';

/// HTTP transport for the checked-in `/widget/v1` visitor contract.
class WidgetApiClient {
  WidgetApiClient({
    required Uri baseUrl,
    required http.Client httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient;

  final Uri _baseUrl;
  final http.Client _httpClient;
  final WidgetRequestEncoder _encoder = const WidgetRequestEncoder();
  final WidgetResponseDecoder _decoder = const WidgetResponseDecoder();
  final Duration requestTimeout;

  Future<WidgetSessionResult> startSession({
    required String widgetKey,
    required WisperBotUser? user,
    required WisperBotStoredSession? storedSession,
    bool preChatCompleted = false,
  }) async {
    final response = await _postJson(
      'session',
      _encoder.sessionBody(
        widgetKey: widgetKey,
        user: user,
        storedSession: storedSession,
      ),
      token: storedSession?.token,
      operation: WidgetOperation.session,
    );
    return _decoder.session(
      response,
      preChatCompleted: preChatCompleted,
    );
  }

  Future<WidgetPollResult> poll({
    required String widgetKey,
    required String token,
    required int after,
  }) async {
    final uri = _endpoint('messages').replace(
      queryParameters: <String, String>{
        'key': widgetKey,
        'after': after.toString(),
      },
    );
    final response = await _execute(
      () => _httpClient
          .get(uri, headers: _headers(token: token, jsonBody: false))
          .timeout(requestTimeout),
      operation: WidgetOperation.poll,
    );
    return _decoder.poll(response);
  }

  Future<WidgetSendResult> sendText({
    required String widgetKey,
    required String token,
    required String text,
  }) async {
    final response = await _postJson(
      'messages',
      _encoder.textBody(widgetKey: widgetKey, text: text),
      token: token,
      operation: WidgetOperation.sendText,
    );
    return _decoder.send(response);
  }

  Future<WidgetSendResult> sendUpload({
    required String widgetKey,
    required String token,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    String? caption,
  }) async {
    final request = _encoder.uploadRequest(
      endpoint: _endpoint('messages'),
      headers: _headers(token: token, jsonBody: false),
      widgetKey: widgetKey,
      upload: upload,
      type: type,
      caption: caption,
    );
    final response = await _execute(
      () async {
        final streamed =
            await _httpClient.send(request).timeout(requestTimeout);
        return http.Response.fromStream(streamed).timeout(requestTimeout);
      },
      operation: WidgetOperation.sendMedia,
    );
    return _decoder.send(response);
  }

  Future<void> setTyping({
    required String widgetKey,
    required String token,
    required bool isTyping,
  }) async {
    await _postJson(
      'typing',
      _encoder.typingBody(widgetKey: widgetKey, isTyping: isTyping),
      token: token,
      operation: WidgetOperation.typing,
    );
  }

  Future<WisperBotHandoffState> requestHandoff({
    required String widgetKey,
    required String token,
  }) async {
    final response = await _postJson(
      'handoff',
      _encoder.handoffBody(widgetKey),
      token: token,
      operation: WidgetOperation.handoff,
    );
    return _decoder.handoff(response);
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, Object> body, {
    String? token,
    required WidgetOperation operation,
  }) =>
      _execute(
        () => _httpClient
            .post(
              _endpoint(path),
              headers: _headers(token: token),
              body: _encoder.jsonBody(body),
            )
            .timeout(requestTimeout),
        operation: operation,
      );

  Future<http.Response> _execute(
    Future<http.Response> Function() request, {
    required WidgetOperation operation,
  }) async {
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw mapWidgetHttpError(response, operation: operation);
      }
      return response;
    } on WisperBotException {
      rethrow;
    } on TimeoutException {
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'The request timed out. Check the connection and try again.',
        retryable: true,
      );
    } on http.ClientException {
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'Could not connect to WisperBot.',
        retryable: true,
      );
    } on Object {
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'Could not complete the network request.',
        retryable: true,
      );
    }
  }

  Uri _endpoint(String path) => widgetEndpoint(_baseUrl, path);

  Map<String, String> _headers({
    String? token,
    bool jsonBody = true,
  }) =>
      widgetHeaders(token: token, jsonBody: jsonBody);
}
