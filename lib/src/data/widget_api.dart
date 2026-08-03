import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../domain/config.dart';
import '../domain/errors.dart';
import '../domain/models.dart';
import 'session_store.dart';

class WidgetSessionResult {
  WidgetSessionResult({
    required this.session,
    required this.widget,
    required this.capabilities,
    required this.identity,
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
  });

  final WisperBotStoredSession session;
  final WisperBotWidgetConfig widget;
  final WisperBotCapabilities capabilities;
  final WisperBotIdentityStatus identity;
  final List<WisperBotMessage> messages;
  final WisperBotSupportAvailability supportAvailability;
  final WisperBotHandoffState handoff;
}

class WidgetPollResult {
  WidgetPollResult({
    required this.messages,
    required this.supportAvailability,
    required this.handoff,
    required this.agentTyping,
  });

  final List<WisperBotMessage> messages;
  final WisperBotSupportAvailability supportAvailability;
  final WisperBotHandoffState handoff;
  final WisperBotAgentTyping? agentTyping;
}

class WidgetSendResult {
  WidgetSendResult({required this.message, required this.handoff});

  final WisperBotMessage message;
  final WisperBotHandoffState handoff;
}

class WidgetApiClient {
  WidgetApiClient({
    required Uri baseUrl,
    required http.Client httpClient,
    this.requestTimeout = const Duration(seconds: 30),
  })  : _baseUrl = baseUrl,
        _httpClient = httpClient;

  static const String sdkVersion = '0.1.0-dev.1';

  final Uri _baseUrl;
  final http.Client _httpClient;
  final Duration requestTimeout;

  Future<WidgetSessionResult> startSession({
    required String widgetKey,
    required WisperBotUser? user,
    required WisperBotStoredSession? storedSession,
  }) async {
    final body = <String, Object>{'key': widgetKey};
    if (storedSession != null) {
      body['visitor_id'] = storedSession.visitorId;
    }
    if (user?.name != null) body['name'] = user!.name!;
    if (user?.email != null) body['email'] = user!.email!;
    if (user?.avatarUrl != null) {
      body['avatar'] = user!.avatarUrl!.toString();
    }
    if (user?.externalId != null) body['external_id'] = user!.externalId!;
    if (user?.signature != null) body['user_hash'] = user!.signature!;

    final response = await _postJson(
      'session',
      body,
      token: storedSession?.token,
      sessionRequest: true,
    );
    final json = _decodeObject(response);
    final visitorId = _requiredString(json, 'visitor_id');
    final token = _requiredString(json, 'token');
    final configJson = _requiredObject(json, 'config');
    final messages = _parseMessages(json['messages']);
    final identity = _parseIdentity(json['identity'], user: user);
    return WidgetSessionResult(
      session: WisperBotStoredSession(
        visitorId: visitorId,
        token: token,
        savedAt: DateTime.now().toUtc(),
      ),
      widget: _parseWidgetConfig(configJson),
      capabilities: _parseCapabilities(json['capabilities']),
      identity: identity,
      messages: messages,
      supportAvailability: _parseAvailability(json['online']),
      handoff: _parseHandoff(json['handoff']),
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
          .get(uri, headers: _headers(token: token))
          .timeout(requestTimeout),
      sessionRequest: false,
    );
    final json = _decodeObject(response);
    final typing = _objectOrNull(json['agent_typing']);
    return WidgetPollResult(
      messages: _parseMessages(json['messages']),
      supportAvailability: _parseAvailability(json['online']),
      handoff: _parseHandoff(json['handoff']),
      agentTyping: typing != null && typing['is_typing'] == true
          ? WisperBotAgentTyping(name: _stringOrNull(typing['name']))
          : null,
    );
  }

  Future<WidgetSendResult> sendText({
    required String widgetKey,
    required String token,
    required String text,
  }) async {
    final response = await _postJson(
      'messages',
      <String, Object>{
        'key': widgetKey,
        'message': text,
        'type': 'text',
      },
      token: token,
      sessionRequest: false,
    );
    return _parseSendResult(response);
  }

  Future<WidgetSendResult> sendUpload({
    required String widgetKey,
    required String token,
    required WisperBotUpload upload,
    required WisperBotMessageType type,
    String? caption,
  }) async {
    _validateUpload(upload, type);
    final request = http.MultipartRequest('POST', _endpoint('messages'))
      ..headers.addAll(_headers(token: token, includeContentType: false))
      ..fields['key'] = widgetKey
      ..fields['type'] = type == WisperBotMessageType.image ? 'image' : 'audio';
    if (caption != null && caption.trim().isNotEmpty) {
      request.fields['message'] = caption.trim();
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        'attachment',
        upload.bytes,
        filename: upload.filename,
      ),
    );
    final response = await _execute(
      () async => http.Response.fromStream(
        await _httpClient.send(request).timeout(requestTimeout),
      ),
      sessionRequest: false,
    );
    return _parseSendResult(response);
  }

  Future<void> setTyping({
    required String widgetKey,
    required String token,
    required bool isTyping,
  }) async {
    await _postJson(
      'typing',
      <String, Object>{'key': widgetKey, 'is_typing': isTyping},
      token: token,
      sessionRequest: false,
    );
  }

  Future<WisperBotHandoffState> requestHandoff({
    required String widgetKey,
    required String token,
  }) async {
    final response = await _postJson(
      'handoff',
      <String, Object>{'key': widgetKey},
      token: token,
      sessionRequest: false,
    );
    return _parseHandoff(_decodeObject(response)['handoff']);
  }

  Future<http.Response> _postJson(
    String path,
    Map<String, Object> body, {
    String? token,
    required bool sessionRequest,
  }) =>
      _execute(
        () => _httpClient
            .post(
              _endpoint(path),
              headers: _headers(token: token),
              body: jsonEncode(body),
            )
            .timeout(requestTimeout),
        sessionRequest: sessionRequest,
      );

  Future<http.Response> _execute(
    Future<http.Response> Function() request, {
    required bool sessionRequest,
  }) async {
    try {
      final response = await request();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _mapHttpError(response, sessionRequest: sessionRequest);
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

  WidgetSendResult _parseSendResult(http.Response response) {
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

  Uri _endpoint(String path) {
    final prefix = _baseUrl.path.endsWith('/')
        ? _baseUrl.path.substring(0, _baseUrl.path.length - 1)
        : _baseUrl.path;
    return _baseUrl.replace(path: '$prefix/widget/v1/$path');
  }

  Map<String, String> _headers({
    String? token,
    bool includeContentType = true,
  }) =>
      <String, String>{
        'Accept': 'application/json',
        'X-WisperBot-SDK': 'flutter/$sdkVersion',
        if (includeContentType) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'X-Widget-Token': token,
      };
}

Map<String, dynamic> _decodeObject(http.Response response) {
  try {
    final value = jsonDecode(utf8.decode(response.bodyBytes));
    if (value is Map<String, dynamic>) return value;
  } on Object {
    // Mapped below without exposing the response body.
  }
  throw WisperBotException(
    code: WisperBotErrorCode.server,
    message: 'WisperBot returned an invalid response.',
    retryable: response.statusCode >= 500,
    httpStatus: response.statusCode,
  );
}

WisperBotException _mapHttpError(
  http.Response response, {
  required bool sessionRequest,
}) {
  final status = response.statusCode;
  final fieldErrors = _safeFieldErrors(response);
  final retryAfterSeconds = int.tryParse(response.headers['retry-after'] ?? '');
  return switch (status) {
    400 => WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'The WisperBot request configuration is invalid.',
        retryable: false,
        httpStatus: status,
        fieldErrors: fieldErrors,
      ),
    401 => WisperBotException(
        code: WisperBotErrorCode.sessionExpired,
        message: 'The chat session expired.',
        retryable: !sessionRequest,
        httpStatus: status,
      ),
    403 => WisperBotException(
        code: WisperBotErrorCode.forbidden,
        message: 'This widget is not allowed for the current application.',
        retryable: false,
        httpStatus: status,
      ),
    404 => WisperBotException(
        code: sessionRequest
            ? WisperBotErrorCode.configuration
            : WisperBotErrorCode.sessionExpired,
        message: sessionRequest
            ? 'The widget is missing or disabled.'
            : 'The chat session is no longer available.',
        retryable: !sessionRequest,
        httpStatus: status,
      ),
    422 => WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'The request could not be validated.',
        retryable: false,
        httpStatus: status,
        fieldErrors: fieldErrors,
      ),
    429 => WisperBotException(
        code: WisperBotErrorCode.rateLimited,
        message: 'Too many requests. Try again shortly.',
        retryable: true,
        httpStatus: status,
        retryAfter: retryAfterSeconds == null
            ? null
            : Duration(seconds: retryAfterSeconds),
      ),
    >= 500 => WisperBotException(
        code: WisperBotErrorCode.server,
        message: 'WisperBot is temporarily unavailable.',
        retryable: true,
        httpStatus: status,
      ),
    _ => WisperBotException(
        code: WisperBotErrorCode.unknown,
        message: 'The request could not be completed.',
        retryable: false,
        httpStatus: status,
      ),
  };
}

Map<String, List<String>> _safeFieldErrors(http.Response response) {
  try {
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> ||
        decoded['errors'] is! Map<String, dynamic>) {
      return const <String, List<String>>{};
    }
    final errors = decoded['errors'] as Map<String, dynamic>;
    return <String, List<String>>{
      for (final entry in errors.entries)
        entry.key: switch (entry.value) {
          List<dynamic> values => values.whereType<String>().take(5).toList(),
          String value => <String>[value],
          _ => const <String>[],
        },
    };
  } on Object {
    return const <String, List<String>>{};
  }
}

List<WisperBotMessage> _parseMessages(Object? value) {
  if (value is! List<dynamic>) return const <WisperBotMessage>[];
  return value
      .whereType<Map<String, dynamic>>()
      .map(_parseMessage)
      .whereType<WisperBotMessage>()
      .toList();
}

WisperBotMessage? _parseMessage(Map<String, dynamic> json) {
  final id = switch (json['id']) {
    int value => value,
    String value => int.tryParse(value),
    _ => null,
  };
  if (id == null) return null;
  final role = switch (json['role']) {
    'visitor' => WisperBotMessageRole.visitor,
    'agent' => WisperBotMessageRole.agent,
    _ => WisperBotMessageRole.unknown,
  };
  final type = switch (json['type']) {
    'text' => WisperBotMessageType.text,
    'image' => WisperBotMessageType.image,
    'audio' => WisperBotMessageType.audio,
    'file' => WisperBotMessageType.file,
    _ => WisperBotMessageType.unknown,
  };
  final sentBy = role == WisperBotMessageRole.visitor
      ? WisperBotSenderKind.visitor
      : switch (json['sent_by']) {
          'human' => WisperBotSenderKind.human,
          'bot' || 'automation' => WisperBotSenderKind.bot,
          _ => WisperBotSenderKind.unknown,
        };
  final attachmentUri = _safeRemoteUri(json['attachment_url']);
  return WisperBotMessage(
    localId: 'server-$id',
    serverId: id,
    role: role,
    type: type,
    body: _stringOrNull(json['body']) ?? '',
    status: WisperBotMessageStatus.sent,
    createdAt:
        DateTime.tryParse(_stringOrNull(json['created_at']) ?? '')?.toLocal() ??
            DateTime.now(),
    attachment: attachmentUri == null
        ? null
        : WisperBotAttachment(
            url: attachmentUri,
            filename: _stringOrNull(json['filename']),
          ),
    senderName: role == WisperBotMessageRole.agent
        ? _stringOrNull(json['agent_name'])
        : null,
    sentBy: sentBy,
  );
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
  if (rawFields is List<dynamic>) {
    for (final field in rawFields) {
      preChatFields.add(
        switch (field) {
          'name' => WisperBotPreChatField.name,
          'email' => WisperBotPreChatField.email,
          _ => WisperBotPreChatField.unknown,
        },
      );
    }
  }
  final rawColor = _stringOrNull(json['primary_color']) ?? '#ff762e';
  final color =
      RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(rawColor) ? rawColor : '#ff762e';
  return WisperBotWidgetConfig(
    title: _stringOrNull(json['title']) ?? 'Chat with us',
    subtitle: _stringOrNull(json['subtitle']) ??
        'We typically reply in a few minutes',
    welcomeMessage:
        _stringOrNull(json['welcome_message']) ?? 'Hi there! How can we help?',
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
    footerCompanyName:
        _stringOrNull(json['footer_company_name']) ?? 'WisperBot',
    teamMembers: members,
    aiEnabled: json['ai_enabled'] == true,
    requiresPreChat: json['require_prechat'] == true,
    preChatFields: preChatFields,
    offlineMessage: _stringOrNull(json['offline_message']),
  );
}

WisperBotCapabilities _parseCapabilities(Object? value) {
  final json = _objectOrNull(value);
  if (json == null) return const WisperBotCapabilities.currentV1();
  final typing = json['typing'];
  return WisperBotCapabilities(
    text: json['text'] != false,
    images: json['images'] != false,
    audio: json['audio'] != false,
    visitorTyping: json['visitor_typing'] == true || typing == true,
    agentTyping: json['agent_typing'] == true || typing == true,
    handoff: json['handoff'] == true,
    backwardPagination: json['backward_pagination'] == true,
    idempotentSends: json['idempotent_sends'] == true,
    unread: json['unread'] == true,
    readReceipts: json['read_receipts'] == true,
    realtime: json['realtime'] == true,
    push: json['push'] == true,
  );
}

WisperBotIdentityStatus _parseIdentity(
  Object? value, {
  required WisperBotUser? user,
}) {
  final json = _objectOrNull(value);
  return switch (json?['status']) {
    'anonymous' => WisperBotIdentityStatus.anonymous,
    'verified' => WisperBotIdentityStatus.verified,
    'rejected' => WisperBotIdentityStatus.rejected,
    _ => user == null
        ? WisperBotIdentityStatus.anonymous
        : WisperBotIdentityStatus.unknown,
  };
}

WisperBotHandoffState _parseHandoff(Object? value) {
  final json = _objectOrNull(value);
  if (json == null || json['enabled'] != true) {
    return const WisperBotHandoffState.unavailable();
  }
  if (json['status'] == 'connected') {
    return const WisperBotHandoffState(
      status: WisperBotHandoffStatus.connected,
    );
  }
  if (json['eligible'] == true) {
    return const WisperBotHandoffState(
      status: WisperBotHandoffStatus.eligible,
    );
  }
  return const WisperBotHandoffState(
    status: WisperBotHandoffStatus.unavailable,
  );
}

WisperBotSupportAvailability _parseAvailability(Object? value) =>
    switch (value) {
      true => WisperBotSupportAvailability.available,
      false => WisperBotSupportAvailability.unavailable,
      _ => WisperBotSupportAvailability.unknown,
    };

void _validateUpload(WisperBotUpload upload, WisperBotMessageType type) {
  if (upload.bytes.isEmpty || upload.bytes.length > 10 * 1024 * 1024) {
    throw const WisperBotException(
      code: WisperBotErrorCode.attachmentRejected,
      message: 'Attachments must be between 1 byte and 10 MB.',
      retryable: false,
    );
  }
  final mime = upload.mimeType.toLowerCase();
  final allowed = type == WisperBotMessageType.image
      ? const <String>{'image/jpeg', 'image/png', 'image/webp'}
      : const <String>{
          'audio/mpeg',
          'audio/aac',
          'audio/mp4',
          'audio/amr',
          'audio/ogg',
          'audio/wav',
          'audio/webm',
          'video/webm',
          'application/ogg',
        };
  if (!allowed.contains(mime)) {
    throw const WisperBotException(
      code: WisperBotErrorCode.attachmentRejected,
      message: 'The attachment type is not supported.',
      retryable: false,
    );
  }
}

Map<String, dynamic> _requiredObject(Map<String, dynamic> json, String key) {
  final value = _objectOrNull(json[key]);
  if (value != null) return value;
  throw const WisperBotException(
    code: WisperBotErrorCode.server,
    message: 'WisperBot returned an incomplete response.',
    retryable: false,
  );
}

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

String? _stringOrNull(Object? value) => value is String ? value : null;

Uri? _safeRemoteUri(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.isAbsolute) return null;
  if (uri.scheme != 'https' && (kReleaseMode || uri.scheme != 'http')) {
    return null;
  }
  return uri;
}
