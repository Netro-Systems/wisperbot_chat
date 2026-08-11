import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../diagnostics/debug_upload_logger.dart';
import '../../domain/errors/wisperbot_exception.dart';
import 'api_endpoints.dart';
import 'http_error_mapper.dart';

/// Central HTTP executor for every WisperBot visitor request.
///
/// This is the only production component that invokes [http.Client]. It owns
/// endpoint resolution, allowed headers, timeouts, multipart execution, and
/// conversion of transport and HTTP failures into safe typed exceptions.
final class NetworkCaller {
  /// Creates a caller using an injected, caller-owned HTTP client.
  NetworkCaller({
    required Uri baseUrl,
    required http.Client httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient;

  final Uri _baseUrl;
  final http.Client _httpClient;

  /// Maximum duration allowed for each transport operation.
  final Duration requestTimeout;

  /// Executes a GET request against a named API [path].
  Future<http.Response> get(
    String path, {
    required WidgetOperation operation,
    required String token,
    Map<String, String> query = const <String, String>{},
  }) {
    final uri = _endpoint(path).replace(queryParameters: query);
    return _execute(
      () => _httpClient
          .get(uri, headers: _headers(token: token, jsonBody: false))
          .timeout(requestTimeout),
      operation: operation,
    );
  }

  /// Downloads a protected media URL with the active widget token.
  Future<http.Response> download(
    Uri uri, {
    required WidgetOperation operation,
    required String token,
    String accept = '*/*',
  }) =>
      _execute(
        () => _httpClient
            .get(
              uri,
              headers: _headers(
                token: token,
                jsonBody: false,
                accept: accept,
              ),
            )
            .timeout(requestTimeout),
        operation: operation,
      );

  /// Executes a JSON POST request against a named API [path].
  Future<http.Response> postJson(
    String path, {
    required WidgetOperation operation,
    required String body,
    String? token,
  }) =>
      _execute(
        () => _httpClient
            .post(
              _endpoint(path),
              headers: _headers(token: token),
              body: body,
            )
            .timeout(requestTimeout),
        operation: operation,
      );

  /// Executes one multipart upload against a named API [path].
  Future<http.Response> upload(
    String path, {
    required WidgetOperation operation,
    required String token,
    required Map<String, String> fields,
    required String fileField,
    required List<int> fileBytes,
    required String filename,
    required String mimeType,
  }) {
    final uploadOperation = mimeType.toLowerCase().startsWith('audio/')
        ? 'audio_upload'
        : 'image_upload';
    final request = http.MultipartRequest('POST', _endpoint(path))
      ..headers.addAll(_headers(token: token, jsonBody: false))
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          fileField,
          fileBytes,
          filename: filename,
          contentType: MediaType.parse(mimeType),
        ),
      );
    if (operation == WidgetOperation.sendMedia) {
      WisperBotDebugUploadLogger.multipartBuilt(
        operation: uploadOperation,
        sizeBytes: fileBytes.length,
        mimeType: mimeType,
      );
    }
    return _execute(
      () async {
        if (operation == WidgetOperation.sendMedia) {
          WisperBotDebugUploadLogger.requestDispatched(uploadOperation);
        }
        final streamed =
            await _httpClient.send(request).timeout(requestTimeout);
        return http.Response.fromStream(streamed).timeout(requestTimeout);
      },
      operation: operation,
      uploadOperation: uploadOperation,
    );
  }

  Future<http.Response> _execute(
    Future<http.Response> Function() request, {
    required WidgetOperation operation,
    String? uploadOperation,
  }) async {
    try {
      final response = await request();
      if (uploadOperation != null) {
        WisperBotDebugUploadLogger.responseReceived(
          uploadOperation,
          response.statusCode,
          response.headers['content-type'],
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw mapWidgetHttpError(response, operation: operation);
      }
      return response;
    } on WisperBotException catch (error) {
      if (uploadOperation != null) {
        WisperBotDebugUploadLogger.failed(uploadOperation, error);
      }
      rethrow;
    } on TimeoutException {
      if (uploadOperation != null) {
        WisperBotDebugUploadLogger.unexpectedFailure(
          uploadOperation,
          TimeoutException('redacted'),
        );
      }
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'The request timed out. Check the connection and try again.',
        retryable: true,
      );
    } on http.ClientException {
      if (uploadOperation != null) {
        WisperBotDebugUploadLogger.unexpectedFailure(
          uploadOperation,
          http.ClientException('redacted'),
        );
      }
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'Could not connect to WisperBot.',
        retryable: true,
      );
    } on Object catch (error) {
      if (uploadOperation != null) {
        WisperBotDebugUploadLogger.unexpectedFailure(uploadOperation, error);
      }
      throw const WisperBotException(
        code: WisperBotErrorCode.network,
        message: 'Could not complete the network request.',
        retryable: true,
      );
    }
  }

  Uri _endpoint(String path) => ApiEndpoints.resolve(_baseUrl, path);

  Map<String, String> _headers({
    String? token,
    bool jsonBody = true,
    String accept = 'application/json',
  }) =>
      <String, String>{
        'Accept': accept,
        if (jsonBody) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'X-Widget-Token': token,
        // Native clients cannot truthfully supply browser Origin or Referer.
      };
}
