/// Builds one deterministic visitor-API message fixture.
Map<String, Object?> message({
  required int id,
  String role = 'agent',
  String type = 'text',
  String body = 'Hello',
  String? sentBy = 'bot',
  String? attachmentUrl,
  String? filename,
  String? mimeType,
}) =>
    <String, Object?>{
      'id': id,
      'role': role,
      'type': type,
      'body': body,
      'sent_by': sentBy,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (filename != null) 'filename': filename,
      if (mimeType != null) 'mime_type': mimeType,
      'created_at': '2026-08-03T10:00:00Z',
      'unknown_message_field': 42,
    };
