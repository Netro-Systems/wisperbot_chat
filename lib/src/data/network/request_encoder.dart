import 'dart:convert';

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

  /// Builds the documented multipart image/audio form fields.
  Map<String, String> uploadFields({
    required String widgetKey,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    required String? caption,
  }) {
    _validateUpload(upload, type);
    final normalizedCaption = caption?.trim() ?? '';
    if (normalizedCaption.length > 4000) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Attachment captions cannot exceed 4,000 characters.',
        retryable: false,
      );
    }
    final fields = <String, String>{
      'key': widgetKey,
      'type': type == WisperBotMessageType.image ? 'image' : 'audio',
      // Match the browser widget's FormData shape. The backend accepts an
      // empty caption, and always including the field avoids a multipart
      // request-shape difference between web and native clients.
      'message': normalizedCaption,
    };
    return fields;
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

    final filename = upload.filename.trim().toLowerCase();
    final mimeType = upload.mimeType.trim().toLowerCase();
    final supported = switch (type) {
      WisperBotMessageType.image => const <String, Set<String>>{
          '.jpg': <String>{'image/jpeg'},
          '.jpeg': <String>{'image/jpeg'},
          '.png': <String>{'image/png'},
          '.webp': <String>{'image/webp'},
        },
      WisperBotMessageType.audio => const <String, Set<String>>{
          '.mp3': <String>{'audio/mpeg'},
          '.aac': <String>{'audio/aac'},
          '.m4a': <String>{'audio/mp4'},
          '.amr': <String>{'audio/amr'},
          '.ogg': <String>{'audio/ogg'},
          '.oga': <String>{'audio/ogg'},
          '.wav': <String>{'audio/wav'},
          '.webm': <String>{'audio/webm'},
        },
      _ => const <String, Set<String>>{},
    };
    final matchingEntry = supported.entries.where(
      (entry) => filename.endsWith(entry.key),
    );
    if (matchingEntry.isEmpty ||
        !matchingEntry.first.value.contains(mimeType)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.attachmentRejected,
        message: 'The attachment filename and MIME type are not supported.',
        retryable: false,
      );
    }
  }
}
