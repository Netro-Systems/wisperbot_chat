import 'package:flutter/foundation.dart';

import 'errors.dart';
import 'realtime.dart';

enum WisperBotChatPhase {
  idle,
  initializing,
  awaitingPreChat,
  ready,
  reconnecting,
  expired,
  failure,
  disposed,
}

enum WisperBotConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

enum WisperBotSupportAvailability { unknown, available, unavailable }

enum WisperBotIdentityStatus { unknown, anonymous, verified, rejected }

enum WisperBotHandoffStatus {
  unavailable,
  eligible,
  requesting,
  connected,
  failed,
}

enum WisperBotLauncherPosition { bottomRight, bottomLeft, unknown }

enum WisperBotPreChatField { name, email, unknown }

enum WisperBotMessageRole { visitor, agent, unknown }

enum WisperBotMessageType { text, image, audio, file, unknown }

enum WisperBotMessageStatus { pending, sent, failed, unconfirmed }

enum WisperBotSenderKind { visitor, bot, human, unknown }

@immutable
class WisperBotCapabilities {
  const WisperBotCapabilities({
    required this.text,
    required this.images,
    required this.audio,
    required this.visitorTyping,
    required this.agentTyping,
    required this.handoff,
    required this.backwardPagination,
    required this.idempotentSends,
    required this.unread,
    required this.readReceipts,
    required this.realtime,
    required this.push,
  });

  const WisperBotCapabilities.none()
      : text = false,
        images = false,
        audio = false,
        visitorTyping = false,
        agentTyping = false,
        handoff = false,
        backwardPagination = false,
        idempotentSends = false,
        unread = false,
        readReceipts = false,
        realtime = false,
        push = false;

  const WisperBotCapabilities.currentV1()
      : text = true,
        images = true,
        audio = true,
        visitorTyping = true,
        agentTyping = true,
        handoff = true,
        backwardPagination = false,
        idempotentSends = false,
        unread = false,
        readReceipts = false,
        realtime = false,
        push = false;

  final bool text;
  final bool images;
  final bool audio;
  final bool visitorTyping;
  final bool agentTyping;
  final bool handoff;
  final bool backwardPagination;
  final bool idempotentSends;
  final bool unread;
  final bool readReceipts;
  final bool realtime;
  final bool push;
}

@immutable
class WisperBotHandoffState {
  const WisperBotHandoffState({required this.status, this.error});

  const WisperBotHandoffState.unavailable()
      : status = WisperBotHandoffStatus.unavailable,
        error = null;

  final WisperBotHandoffStatus status;
  final WisperBotException? error;
}

@immutable
class WisperBotAgentTyping {
  const WisperBotAgentTyping({this.name});

  final String? name;
}

@immutable
class WisperBotTeamMember {
  const WisperBotTeamMember({required this.name, this.avatarUrl});

  final String name;
  final Uri? avatarUrl;
}

@immutable
class WisperBotWidgetConfig {
  WisperBotWidgetConfig({
    required this.title,
    required this.subtitle,
    required this.welcomeMessage,
    required this.agentName,
    required this.primaryColorHex,
    required this.launcherPosition,
    required this.footerCompanyName,
    required List<WisperBotTeamMember> teamMembers,
    required this.aiEnabled,
    required this.requiresPreChat,
    required List<WisperBotPreChatField> preChatFields,
    this.avatarUrl,
    this.launcherText,
    this.launcherLogoUrl,
    this.offlineMessage,
  })  : teamMembers = List<WisperBotTeamMember>.unmodifiable(teamMembers),
        preChatFields = List<WisperBotPreChatField>.unmodifiable(preChatFields);

  final String title;
  final String subtitle;
  final String welcomeMessage;
  final String agentName;
  final Uri? avatarUrl;
  final String primaryColorHex;
  final WisperBotLauncherPosition launcherPosition;
  final String? launcherText;
  final Uri? launcherLogoUrl;
  final String footerCompanyName;
  final List<WisperBotTeamMember> teamMembers;
  final bool aiEnabled;
  final bool requiresPreChat;
  final List<WisperBotPreChatField> preChatFields;
  final String? offlineMessage;
}

@immutable
class WisperBotAttachment {
  const WisperBotAttachment({
    required this.url,
    this.filename,
    this.mimeType,
  });

  final Uri url;
  final String? filename;
  final String? mimeType;
}

@immutable
class WisperBotUpload {
  WisperBotUpload({
    required Uint8List bytes,
    required this.filename,
    required this.mimeType,
  }) : bytes = Uint8List.fromList(bytes);

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

@immutable
class WisperBotMessage {
  const WisperBotMessage({
    required this.localId,
    required this.role,
    required this.type,
    required this.body,
    required this.status,
    required this.createdAt,
    this.serverId,
    this.attachment,
    this.senderName,
    this.sentBy,
    this.error,
  });

  final String localId;
  final int? serverId;
  final WisperBotMessageRole role;
  final WisperBotMessageType type;
  final String body;
  final WisperBotMessageStatus status;
  final DateTime createdAt;
  final WisperBotAttachment? attachment;
  final String? senderName;
  final WisperBotSenderKind? sentBy;
  final WisperBotException? error;

  WisperBotMessage copyWith({
    String? localId,
    int? serverId,
    WisperBotMessageRole? role,
    WisperBotMessageType? type,
    String? body,
    WisperBotMessageStatus? status,
    DateTime? createdAt,
    WisperBotAttachment? attachment,
    String? senderName,
    WisperBotSenderKind? sentBy,
    WisperBotException? error,
    bool clearError = false,
  }) =>
      WisperBotMessage(
        localId: localId ?? this.localId,
        serverId: serverId ?? this.serverId,
        role: role ?? this.role,
        type: type ?? this.type,
        body: body ?? this.body,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        attachment: attachment ?? this.attachment,
        senderName: senderName ?? this.senderName,
        sentBy: sentBy ?? this.sentBy,
        error: clearError ? null : error ?? this.error,
      );
}

@immutable
class WisperBotChatState {
  WisperBotChatState({
    required this.phase,
    required List<WisperBotMessage> messages,
    required this.connection,
    this.realtime = WisperBotRealtimeStatus.disabled,
    required this.widget,
    required this.capabilities,
    required this.identity,
    required this.handoff,
    required this.supportAvailability,
    required this.visitorTyping,
    required this.agentTyping,
    required this.pendingCount,
    required this.unreadCount,
    this.error,
  }) : messages = List<WisperBotMessage>.unmodifiable(messages);

  factory WisperBotChatState.initial() => WisperBotChatState(
        phase: WisperBotChatPhase.idle,
        messages: const <WisperBotMessage>[],
        connection: WisperBotConnectionState.disconnected,
        realtime: WisperBotRealtimeStatus.disabled,
        widget: null,
        capabilities: const WisperBotCapabilities.none(),
        identity: WisperBotIdentityStatus.unknown,
        handoff: const WisperBotHandoffState.unavailable(),
        supportAvailability: WisperBotSupportAvailability.unknown,
        visitorTyping: false,
        agentTyping: null,
        pendingCount: 0,
        unreadCount: null,
      );

  final WisperBotChatPhase phase;
  final List<WisperBotMessage> messages;
  final WisperBotConnectionState connection;
  final WisperBotRealtimeStatus realtime;
  final WisperBotWidgetConfig? widget;
  final WisperBotCapabilities capabilities;
  final WisperBotIdentityStatus identity;
  final WisperBotHandoffState handoff;
  final WisperBotSupportAvailability supportAvailability;
  final bool visitorTyping;
  final WisperBotAgentTyping? agentTyping;
  final int pendingCount;
  final int? unreadCount;
  final WisperBotException? error;

  WisperBotChatState copyWith({
    WisperBotChatPhase? phase,
    List<WisperBotMessage>? messages,
    WisperBotConnectionState? connection,
    WisperBotRealtimeStatus? realtime,
    Object? widget = _notProvided,
    WisperBotCapabilities? capabilities,
    WisperBotIdentityStatus? identity,
    WisperBotHandoffState? handoff,
    WisperBotSupportAvailability? supportAvailability,
    bool? visitorTyping,
    Object? agentTyping = _notProvided,
    int? pendingCount,
    Object? unreadCount = _notProvided,
    Object? error = _notProvided,
  }) =>
      WisperBotChatState(
        phase: phase ?? this.phase,
        messages: messages ?? this.messages,
        connection: connection ?? this.connection,
        realtime: realtime ?? this.realtime,
        widget: identical(widget, _notProvided)
            ? this.widget
            : widget as WisperBotWidgetConfig?,
        capabilities: capabilities ?? this.capabilities,
        identity: identity ?? this.identity,
        handoff: handoff ?? this.handoff,
        supportAvailability: supportAvailability ?? this.supportAvailability,
        visitorTyping: visitorTyping ?? this.visitorTyping,
        agentTyping: identical(agentTyping, _notProvided)
            ? this.agentTyping
            : agentTyping as WisperBotAgentTyping?,
        pendingCount: pendingCount ?? this.pendingCount,
        unreadCount: identical(unreadCount, _notProvided)
            ? this.unreadCount
            : unreadCount as int?,
        error: identical(error, _notProvided)
            ? this.error
            : error as WisperBotException?,
      );
}

const Object _notProvided = Object();
