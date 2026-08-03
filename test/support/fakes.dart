import 'package:wisperbot_chat/wisperbot_chat.dart';

class MemorySessionStore implements WisperBotSessionStore {
  final Map<String, WisperBotStoredSession> values =
      <String, WisperBotStoredSession>{};
  final List<String> reads = <String>[];
  final List<String> writes = <String>[];
  final List<String> deletes = <String>[];

  @override
  Future<WisperBotStoredSession?> read(String namespace) async {
    reads.add(namespace);
    return values[namespace];
  }

  @override
  Future<void> write(
    String namespace,
    WisperBotStoredSession session,
  ) async {
    writes.add(namespace);
    values[namespace] = session;
  }

  @override
  Future<void> delete(String namespace) async {
    deletes.add(namespace);
    values.remove(namespace);
  }
}

Map<String, Object?> sessionResponse({
  String visitorId = 'visitor-1',
  String token = 'token-1',
  List<Map<String, Object?>> messages = const <Map<String, Object?>>[],
  bool requirePreChat = false,
  bool online = true,
  Map<String, Object?>? capabilities,
}) =>
    <String, Object?>{
      'visitor_id': visitorId,
      'token': token,
      'config': <String, Object?>{
        'key': 'test-widget',
        'title': 'Test support',
        'subtitle': 'Usually replies quickly',
        'welcome_message': 'Welcome to the test chat',
        'agent_name': 'Support',
        'primary_color': '#6258f9',
        'position': 'bottom_right',
        'footer_company_name': 'WisperBot',
        'team_members': <Object?>[],
        'ai_enabled': true,
        'require_prechat': requirePreChat,
        'prechat_fields': <String>['name', 'email'],
        'unknown_config_field': 'ignored',
      },
      'online': online,
      'messages': messages,
      'handoff': <String, Object?>{
        'enabled': true,
        'eligible': false,
        'status': 'bot',
      },
      if (capabilities != null) 'capabilities': capabilities,
      'unknown_root_field': <String, Object?>{'safe': true},
    };

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

Map<String, Object?> pollResponse({
  List<Map<String, Object?>> messages = const <Map<String, Object?>>[],
  bool online = true,
  bool typing = false,
}) =>
    <String, Object?>{
      'messages': messages,
      'online': online,
      'handoff': <String, Object?>{
        'enabled': true,
        'eligible': true,
        'status': 'bot',
      },
      'agent_typing': <String, Object?>{
        'is_typing': typing,
        'name': typing ? 'Taylor' : null,
      },
    };
