/// Builds one deterministic visitor-API message fixture.
Map<String, Object?> message({
  required int id,
  String role = 'agent',
  String type = 'text',
  String body = 'Hello',
  String? sentBy = 'bot',
}) =>
    <String, Object?>{
      'id': id,
      'role': role,
      'type': type,
      'body': body,
      'sent_by': sentBy,
      'created_at': '2026-08-03T10:00:00Z',
      'unknown_message_field': 42,
    };
