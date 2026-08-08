import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../configuration/wisperbot_config.dart';
import '../../domain/contracts/session_store.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';

/// Encodes the exact request shapes accepted by the visitor widget API.
///
/// Keeping field selection here prevents transport changes from accidentally
/// inventing credentials, browser headers, or backend fields.
final class WidgetRequestEncoder {
  /// Creates the stateless request encoder.
  const WidgetRequestEncoder();

  /// Encodes a session creation or restoration body.
  Map<String, Object> sessionBody({
    required String widgetKey,
    required WisperBotUser? user,
    required WisperBotStoredSession? storedSession,
  }) =>
      <String, Object>{
        'key': widgetKey,
        if (storedSession != null) 'visitor_id': storedSession.visitorId,
        if (user?.name != null) 'name': user!.name!,
        if (user?.email != null) 'email': user!.email!,
        if (user?.avatarUrl != null) 'avatar': user!.avatarUrl!.toString(),
        if (user?.externalId != null) 'external_id': user!.externalId!,
        if (user?.signature != null) 'user_hash': user!.signature!,
      };

  /// Encodes a text-send body.
  Map<String, Object> textBody({
    required String widgetKey,
    required String text,
  }) =>
      <String, Object>{'key': widgetKey, 'message': text};

  /// Encodes a visitor-typing body.
  Map<String, Object> typingBody({
    required String widgetKey,
    required bool isTyping,
  }) =>
      <String, Object>{'key': widgetKey, 'is_typing': isTyping};

  /// Encodes a human-handoff body.
  Map<String, Object> handoffBody(String widgetKey) =>
      <String, Object>{'key': widgetKey};

  /// Encodes a JSON request body without exposing maps outside data.
  String jsonBody(Map<String, Object> body) => jsonEncode(body);

  /// Builds the documented multipart image/audio request.
  http.MultipartRequest uploadRequest({
    required Uri endpoint,
    required Map<String, String> headers,
    required String widgetKey,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    required String? caption,
  }) {
    _validateUpload(upload, type);
    final request = http.MultipartRequest('POST', endpoint)
      ..headers.addAll(headers)
      ..fields['key'] = widgetKey
      ..fields['type'] = type == WisperBotMessageType.image ? 'image' : 'audio'
      ..files.add(
        http.MultipartFile.fromBytes(
          'attachment',
          upload.bytes,
          filename: upload.filename,
        ),
      );
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['message'] = caption.trim();
    }
    return request;
  }

  void _validateUpload(WisperBotUpload upload, WisperBotMessageType type) {
    if (upload.bytes.isEmpty || upload.bytes.length > 10 * 1024 * 1024) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'Attachments must be between 1 byte and 10 MB.',
        retryable: false,
      );
    }
    if (upload.filename.trim().isEmpty ||
        (type != WisperBotMessageType.image &&
            type != WisperBotMessageType.audio)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'The attachment filename or message type is invalid.',
        retryable: false,
      );
    }
  }
}
