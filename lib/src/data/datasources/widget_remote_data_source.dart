import 'dart:typed_data';

import '../../configuration/wisperbot_config.dart';
import '../../domain/contracts/session_store.dart';
import '../../domain/models/models.dart';
import '../network/api_endpoints.dart';
import '../network/http_error_mapper.dart';
import '../network/network_caller.dart';
import '../network/request_encoder.dart';
import '../network/response_decoder.dart';
import '../network/widget_results.dart';

/// Backend operations required by the WisperBot application runtime.
abstract interface class WidgetRemoteDataSource {
  Future<WidgetSessionResult> startSession({
    required String widgetKey,
    required WisperBotUser? user,
    required WisperBotStoredSession? storedSession,
    bool preChatCompleted = false,
    String? deviceId,
  });

  Future<WidgetPollResult> poll({
    required String widgetKey,
    required String token,
    required int after,
  });

  Future<WidgetSendResult> sendText({
    required String widgetKey,
    required String token,
    required String text,
  });

  Future<WidgetSendResult> sendUpload({
    required String widgetKey,
    required String token,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    String? caption,
  });

  Future<Uint8List> loadAttachmentBytes({
    required String token,
    required WisperBotAttachment attachment,
  });

  Future<void> setTyping({
    required String widgetKey,
    required String token,
    required bool isTyping,
  });

  Future<WisperBotHandoffState> requestHandoff({
    required String widgetKey,
    required String token,
  });

  Future<void> markRead({
    required String widgetKey,
    required String token,
  });
}

/// HTTP implementation of the visitor widget remote data source.
///
/// It selects named endpoints and translates between wire payloads and typed
/// SDK results. All actual transport execution is delegated to [NetworkCaller].
final class HttpWidgetRemoteDataSource implements WidgetRemoteDataSource {
  /// Creates a data source backed by [networkCaller].
  HttpWidgetRemoteDataSource({required NetworkCaller networkCaller})
      : _networkCaller = networkCaller;

  final NetworkCaller _networkCaller;
  final WidgetRequestEncoder _encoder = const WidgetRequestEncoder();
  final WidgetResponseDecoder _decoder = const WidgetResponseDecoder();

  @override
  Future<WidgetSessionResult> startSession({
    required String widgetKey,
    required WisperBotUser? user,
    required WisperBotStoredSession? storedSession,
    bool preChatCompleted = false,
    String? deviceId,
  }) async {
    final body = _encoder.sessionBody(
      widgetKey: widgetKey,
      user: user,
      storedSession: storedSession,
      deviceId: deviceId,
    );
    final response = await _networkCaller.postJson(
      ApiEndpoints.session,
      body: _encoder.jsonBody(body),
      token: storedSession?.token,
      operation: WidgetOperation.session,
    );
    return _decoder.session(response, preChatCompleted: preChatCompleted);
  }

  @override
  Future<WidgetPollResult> poll({
    required String widgetKey,
    required String token,
    required int after,
  }) async {
    final response = await _networkCaller.get(
      ApiEndpoints.messages,
      token: token,
      query: <String, String>{
        'key': widgetKey,
        'after': after.toString(),
        'active': '1',
        'open': '1',
      },
      operation: WidgetOperation.poll,
    );
    return _decoder.poll(response);
  }

  @override
  Future<void> markRead({
    required String widgetKey,
    required String token,
  }) async {
    await _networkCaller.postJson(
      ApiEndpoints.read,
      body: _encoder.jsonBody(_encoder.readBody(widgetKey)),
      token: token,
      operation: WidgetOperation.read,
    );
  }

  @override
  Future<WidgetSendResult> sendText({
    required String widgetKey,
    required String token,
    required String text,
  }) async {
    final response = await _networkCaller.postJson(
      ApiEndpoints.messages,
      body: _encoder.jsonBody(
        _encoder.textBody(widgetKey: widgetKey, text: text),
      ),
      token: token,
      operation: WidgetOperation.sendText,
    );
    return _decoder.send(response);
  }

  @override
  Future<WidgetSendResult> sendUpload({
    required String widgetKey,
    required String token,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    String? caption,
  }) async {
    final fields = _encoder.uploadFields(
      widgetKey: widgetKey,
      upload: upload,
      type: type,
      caption: caption,
    );
    final response = await _networkCaller.upload(
      ApiEndpoints.messages,
      token: token,
      fields: fields,
      fileField: 'attachment',
      fileBytes: upload.bytes,
      filename: upload.filename,
      mimeType: upload.mimeType,
      operation: WidgetOperation.sendMedia,
    );
    return _decoder.send(response);
  }

  @override
  Future<Uint8List> loadAttachmentBytes({
    required String token,
    required WisperBotAttachment attachment,
  }) async {
    final response = await _networkCaller.download(
      attachment.url,
      token: token,
      operation: WidgetOperation.media,
      accept: attachment.mimeType?.startsWith('audio/') == true ? 'audio/*,*/*' : '*/*',
    );
    return response.bodyBytes;
  }

  @override
  Future<void> setTyping({
    required String widgetKey,
    required String token,
    required bool isTyping,
  }) async {
    await _networkCaller.postJson(
      ApiEndpoints.typing,
      body: _encoder.jsonBody(
        _encoder.typingBody(widgetKey: widgetKey, isTyping: isTyping),
      ),
      token: token,
      operation: WidgetOperation.typing,
    );
  }

  @override
  Future<WisperBotHandoffState> requestHandoff({
    required String widgetKey,
    required String token,
  }) async {
    final response = await _networkCaller.postJson(
      ApiEndpoints.handoff,
      body: _encoder.jsonBody(_encoder.handoffBody(widgetKey)),
      token: token,
      operation: WidgetOperation.handoff,
    );
    return _decoder.handoff(response);
  }
}
