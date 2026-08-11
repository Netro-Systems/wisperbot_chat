Map<String, Object?> sessionResponse({
  String visitorId = 'visitor-1',
  String token = 'token-1',
  List<Map<String, Object?>> messages = const <Map<String, Object?>>[],
  bool requirePreChat = false,
  bool online = true,
  String? avatarUrl,
  String? launcherLogoUrl,
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
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        'primary_color': '#6258f9',
        'position': 'bottom_right',
        'footer_company_name': 'WisperBot',
        if (launcherLogoUrl != null) 'launcher_logo_url': launcherLogoUrl,
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
      'unknown_root_field': <String, Object?>{'safe': true},
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
