import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/contracts/session_store.dart';
import '../../domain/errors/wisperbot_exception.dart';
import '../../domain/models/models.dart';
import 'widget_results.dart';

/// Strictly decodes visitor API responses into immutable SDK values.
///
/// Raw JSON and response bodies never leave this data-layer component.
final class WidgetResponseDecoder {
  /// Creates the stateless response decoder.
  const WidgetResponseDecoder();

  /// Decodes a session creation or restoration response.
  WidgetSessionResult session(
    http.Response response, {
    required bool preChatCompleted,
  }) {
    final json = _decodeObject(response);
    final visitorId = _requiredString(json, 'visitor_id');
    final token = _requiredString(json, 'token');
    final conversationId = _requiredInt(json, 'conversation_id');
    final configJson = _requiredObject(json, 'config');
    return WidgetSessionResult(
      session: WisperBotStoredSession(
        visitorId: visitorId,
        token: token,
        savedAt: DateTime.now().toUtc(),
        preChatCompleted: preChatCompleted,
      ),
      conversationId: conversationId,
      widget: _parseWidgetConfig(configJson),
      messages: _parseMessages(json['messages']),
      supportAvailability: _parseAvailability(_requiredBool(json, 'online')),
      handoff: _parseHandoff(json['handoff']),
    );
  }

  /// Decodes one forward-poll response.
  WidgetPollResult poll(http.Response response) {
    final json = _decodeObject(response);
    final typing = _requiredObject(json, 'agent_typing');
    final isTyping = _requiredBool(typing, 'is_typing');
    final typingName = typing['name'];
    if (typingName != null && typingName is! String) {
      throw _invalidResponse();
    }
    return WidgetPollResult(
      messages: _parseMessages(json['messages']),
      supportAvailability: _parseAvailability(_requiredBool(json, 'online')),
      handoff: _parseHandoff(json['handoff']),
      agentTyping: isTyping ? WisperBotAgentTyping(name: typingName as String?) : null,
    );
  }

  /// Decodes a visitor-send confirmation.
  WidgetSendResult send(http.Response response) {
    final json = _decodeObject(response);
    final messageJson = _requiredObject(json, 'message');
    final message = _parseMessage(messageJson);
    if (message == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.server,
        message: 'WisperBot returned an invalid message.',
        retryable: false,
      );
    }
    return WidgetSendResult(
      message: message,
      handoff: _parseHandoff(json['handoff']),
    );
  }

  /// Decodes a handoff response.
  WisperBotHandoffState handoff(http.Response response) =>
      _parseHandoff(_decodeObject(response)['handoff']);

  /// Decodes the widget-safe realtime payload for one created message.
  WisperBotMessage? realtimeMessage(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final messageJson = value['message'];
    if (messageJson is! Map<String, dynamic>) return null;
    return _parseMessage(messageJson);
  }

  /// Decodes the widget-safe realtime payload for agent typing changes.
  WisperBotAgentTyping? realtimeTyping(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final typing = value['agent_typing'];
    if (typing is! Map<String, dynamic>) return null;
    final isTyping = typing['is_typing'];
    if (isTyping is! bool) return null;
    final name = typing['name'];
    if (name != null && name is! String) return null;
    return isTyping ? WisperBotAgentTyping(name: name as String?) : null;
  }

  /// Decodes the widget-safe realtime payload for human-handoff updates.
  WisperBotHandoffState? realtimeHandoff(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final handoff = value['handoff'];
    if (handoff is! Map<String, dynamic>) return null;
    return _parseHandoff(handoff);
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map<String, dynamic>) return value;
    } on Object {
      // The safe typed failure below deliberately excludes response contents.
    }
    throw WisperBotException(
      code: WisperBotErrorCode.server,
      message: 'WisperBot returned an invalid response.',
      retryable: response.statusCode >= 500,
      httpStatus: response.statusCode,
    );
  }

  List<WisperBotMessage> _parseMessages(Object? value) {
    if (value is! List<dynamic>) {
      throw const WisperBotException(
        code: WisperBotErrorCode.server,
        message: 'WisperBot returned an incomplete response.',
        retryable: false,
      );
    }
    final messages = <WisperBotMessage>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) {
        throw const WisperBotException(
          code: WisperBotErrorCode.server,
          message: 'WisperBot returned an invalid message.',
          retryable: false,
        );
      }
      final message = _parseMessage(item);
      if (message == null) {
        throw const WisperBotException(
          code: WisperBotErrorCode.server,
          message: 'WisperBot returned an invalid message.',
          retryable: false,
        );
      }
      messages.add(message);
    }
    return messages;
  }

  WisperBotMessage? _parseMessage(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int && rawId > 0 ? rawId : null;
    final createdAt = DateTime.tryParse(_stringOrNull(json['created_at']) ?? '');
    if (id == null || createdAt == null || json['body'] is! String) return null;
    final role = switch (json['role']) {
      'visitor' => WisperBotMessageRole.visitor,
      'agent' => WisperBotMessageRole.agent,
      _ => WisperBotMessageRole.unknown,
    };

    final attachmentData = json['attachment'] ?? json['media'] ?? json['payload'];
    String? rawAttachmentUrl = _stringOrNull(json['attachment_url']) ??
        _stringOrNull(json['file_url']) ??
        _stringOrNull(json['media_url']);
    String? filename = _stringOrNull(json['filename']) ?? _stringOrNull(json['file_name']);
    String? mimeType = _stringOrNull(json['mime_type']) ?? _stringOrNull(json['mimeType']);

    if (rawAttachmentUrl == null) {
      if (attachmentData is String && attachmentData.trim().isNotEmpty) {
        rawAttachmentUrl = attachmentData.trim();
      } else if (attachmentData is Map<String, dynamic>) {
        rawAttachmentUrl = _stringOrNull(
          attachmentData['url'] ??
              attachmentData['preview_url'] ??
              attachmentData['path'] ??
              attachmentData['link'],
        );
        filename ??= _stringOrNull(
          attachmentData['filename'] ?? attachmentData['name'] ?? attachmentData['file_name'],
        );
        mimeType ??= _stringOrNull(
          attachmentData['mime_type'] ?? attachmentData['mimeType'],
        );
      }
    }

    final attachmentUri = _safeRemoteUri(rawAttachmentUrl);
    final rawType = _stringOrNull(json['type'])?.toLowerCase();
    final type = _inferWisperBotMessageType(
      rawType: rawType,
      filename: filename,
      mimeType: mimeType,
      url: rawAttachmentUrl,
      hasAttachment: attachmentUri != null,
    );

    final sentBy = role == WisperBotMessageRole.visitor
        ? WisperBotSenderKind.visitor
        : switch (json['sent_by']) {
            'human' => WisperBotSenderKind.human,
            'bot' => WisperBotSenderKind.bot,
            'automation' => WisperBotSenderKind.automation,
            'broadcast' => WisperBotSenderKind.broadcast,
            _ => WisperBotSenderKind.unknown,
          };

    return WisperBotMessage(
      localId: 'server-$id',
      serverId: id,
      role: role,
      type: type,
      body: json['body'] as String,
      status: _parseDeliveryStatus(json),
      createdAt: createdAt.toLocal(),
      attachment: attachmentUri == null
          ? null
          : WisperBotAttachment(
              url: attachmentUri,
              filename: filename,
              mimeType: mimeType,
            ),
      senderName: role == WisperBotMessageRole.agent ? _stringOrNull(json['agent_name']) : null,
      sentBy: sentBy,
    );
  }

  WisperBotMessageType _inferWisperBotMessageType({
    String? rawType,
    String? filename,
    String? mimeType,
    String? url,
    bool hasAttachment = false,
  }) {
    if (rawType == 'image') return WisperBotMessageType.image;
    if (rawType == 'audio' || rawType == 'voice') {
      return WisperBotMessageType.audio;
    }
    if (rawType == 'file' ||
        rawType == 'document' ||
        rawType == 'pdf' ||
        rawType == 'doc' ||
        rawType == 'attachment' ||
        rawType == 'media') {
      return WisperBotMessageType.file;
    }

    final nameOrPath = (filename ?? url ?? '').toLowerCase();
    final mime = (mimeType ?? '').toLowerCase();

    if (mime.startsWith('image/') ||
        RegExp(r'\.(jpg|jpeg|png|webp|gif|svg|heic|heif)$').hasMatch(nameOrPath)) {
      return WisperBotMessageType.image;
    }
    if (mime.startsWith('audio/') ||
        RegExp(r'\.(mp3|wav|m4a|aac|ogg|oga|webm|opus|amr)$').hasMatch(nameOrPath)) {
      return WisperBotMessageType.audio;
    }
    if (hasAttachment) {
      return WisperBotMessageType.file;
    }

    return switch (rawType) {
      'text' => WisperBotMessageType.text,
      _ => WisperBotMessageType.unknown,
    };
  }

  WisperBotMessageStatus _parseDeliveryStatus(Map<String, dynamic> json) {
    if (json['read_at'] != null ||
        json['is_read'] == true ||
        json['read'] == true ||
        json['seen'] == true ||
        json['is_seen'] == true) {
      return WisperBotMessageStatus.read;
    }

    if (json['delivered_at'] != null || json['is_delivered'] == true || json['delivered'] == true) {
      return WisperBotMessageStatus.delivered;
    }

    final raw = (json['delivery_status'] ??
            json['delivery_state'] ??
            json['deliveryStatus'] ??
            json['message_status'] ??
            json['status'] ??
            json['state'])
        ?.toString()
        .trim()
        .toLowerCase();

    return switch (raw) {
      'read' || 'seen' || 'viewed' || 'opened' => WisperBotMessageStatus.read,
      'delivered' || 'received' || 'reached' => WisperBotMessageStatus.delivered,
      'failed' || 'error' || 'undelivered' || 'rejected' => WisperBotMessageStatus.failed,
      'sending' || 'pending' || 'queued' => WisperBotMessageStatus.pending,
      'unconfirmed' => WisperBotMessageStatus.unconfirmed,
      _ => WisperBotMessageStatus.sent,
    };
  }

  WisperBotWidgetConfig _parseWidgetConfig(Map<String, dynamic> json) {
    final members = <WisperBotTeamMember>[];
    final rawMembers = json['team_members'];
    if (rawMembers is List<dynamic>) {
      for (final item in rawMembers.whereType<Map<String, dynamic>>().take(5)) {
        final name = _stringOrNull(item['name']);
        if (name != null && name.isNotEmpty) {
          members.add(
            WisperBotTeamMember(
              name: name,
              avatarUrl: _safeRemoteUri(item['avatar_url']),
            ),
          );
        }
      }
    }
    final preChatFields = <WisperBotPreChatField>[];
    final rawFields = json['prechat_fields'];
    if (rawFields is! List<dynamic>) throw _invalidResponse();
    for (final field in rawFields) {
      preChatFields.add(
        switch (field) {
          'name' => WisperBotPreChatField.name,
          'email' => WisperBotPreChatField.email,
          _ => WisperBotPreChatField.unknown,
        },
      );
    }
    final rawColor = _stringOrNull(json['primary_color']) ?? '#ff762e';
    final color = RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(rawColor) ? rawColor : '#ff762e';
    return WisperBotWidgetConfig(
      title: _stringOrNull(json['title']) ?? 'Chat with us',
      subtitle: _stringOrNull(json['subtitle']) ?? 'We typically reply in a few minutes',
      welcomeMessage: _stringOrNull(json['welcome_message']) ?? 'Hi there! How can we help?',
      agentName: _stringOrNull(json['agent_name']) ?? 'Support',
      avatarUrl: _safeRemoteUri(json['avatar_url']),
      primaryColorHex: color,
      launcherPosition: switch (json['position']) {
        'bottom_right' => WisperBotLauncherPosition.bottomRight,
        'bottom_left' => WisperBotLauncherPosition.bottomLeft,
        _ => WisperBotLauncherPosition.unknown,
      },
      launcherText: _stringOrNull(json['launcher_text']),
      launcherLogoUrl: _safeRemoteUri(json['launcher_logo_url']),
      footerCompanyName: _stringOrNull(json['footer_company_name']) ?? 'WisperBot',
      teamMembers: members,
      aiEnabled: _requiredBool(json, 'ai_enabled'),
      requiresPreChat: _requiredBool(json, 'require_prechat'),
      preChatFields: preChatFields,
      realtime: _parseRealtimeConfig(json['realtime']),
      offlineMessage: _stringOrNull(json['offline_message']),
    );
  }

  WisperBotRealtimeConfig? _parseRealtimeConfig(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final authEndpoint = _safeRemoteUri(value['auth_endpoint']);
    if (authEndpoint == null) return null;
    return WisperBotRealtimeConfig(
      key: _stringOrNull(value['key']) ?? '',
      cluster: _stringOrNull(value['cluster']) ?? 'mt1',
      authEndpoint: authEndpoint,
    );
  }

  WisperBotHandoffState _parseHandoff(Object? value) {
    if (value is! Map<String, dynamic>) throw _invalidResponse();
    final enabled = _requiredBool(value, 'enabled');
    final eligible = _requiredBool(value, 'eligible');
    if (value['status'] is! String) throw _invalidResponse();
    if (!enabled) {
      return const WisperBotHandoffState.unavailable();
    }
    if (value['status'] == 'connected') {
      return const WisperBotHandoffState(
        status: WisperBotHandoffStatus.connected,
      );
    }
    if (eligible) {
      return const WisperBotHandoffState(
        status: WisperBotHandoffStatus.eligible,
      );
    }
    return const WisperBotHandoffState(
      status: WisperBotHandoffStatus.unavailable,
    );
  }

  WisperBotSupportAvailability _parseAvailability(Object? value) => switch (value) {
        true => WisperBotSupportAvailability.available,
        false => WisperBotSupportAvailability.unavailable,
        _ => WisperBotSupportAvailability.unknown,
      };

  Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
    final value = _objectOrNull(json[key]);
    if (value != null) return value;
    throw _invalidResponse();
  }

  bool _requiredBool(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw _invalidResponse();
  }

  WisperBotException _invalidResponse() => const WisperBotException(
        code: WisperBotErrorCode.server,
        message: 'WisperBot returned an incomplete response.',
        retryable: false,
      );

  Map<String, dynamic>? _objectOrNull(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  String _requiredString(Map<String, dynamic> json, String key) {
    final value = _stringOrNull(json[key]);
    if (value != null && value.isNotEmpty) return value;
    throw const WisperBotException(
      code: WisperBotErrorCode.server,
      message: 'WisperBot returned an incomplete response.',
      retryable: false,
    );
  }

  int _requiredInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw _invalidResponse();
  }

  String? _stringOrNull(Object? value) => value is String ? value : null;

  Uri? _safeRemoteUri(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    final text = value.trim();
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    if (uri.isAbsolute && uri.scheme != 'https' && uri.scheme != 'http') {
      return null;
    }
    return uri;
  }
}
