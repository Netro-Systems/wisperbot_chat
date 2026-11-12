part of 'models.dart';

/// Message direction represented by the visitor API.
enum WisperBotMessageRole { visitor, agent, unknown }

/// Supported message content categories.
enum WisperBotMessageType { text, image, audio, file, unknown }

/// Delivery state of a message in controller state.
enum WisperBotMessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
  unconfirmed;

  /// Alias for read status.
  static const WisperBotMessageStatus seen = WisperBotMessageStatus.read;
}

/// Backend-reported sender category.
enum WisperBotSenderKind { visitor, bot, human, automation, broadcast, unknown }

/// Optional image supplied alongside a lookup reply.
final class WisperBotLookupImage {
  /// Creates a lookup image with an optional accessible label.
  const WisperBotLookupImage({required this.url, this.label = ''});

  /// Remote image URL.
  final Uri url;

  /// Server-supplied description of the image.
  final String label;
}

/// Immutable chat message visible to headless and prebuilt integrations.
class WisperBotMessage {
  /// Creates a message with local and optional server identity.
  const WisperBotMessage({
    required this.localId,
    required this.role,
    required this.type,
    required this.body,
    required this.status,
    required this.createdAt,
    this.serverId,
    this.attachment,
    this.lookupImages = const <WisperBotLookupImage>[],
    this.localUpload,
    this.senderName,
    this.isActivity = false,
    this.sentBy,
    this.error,
  });

  /// SDK-local identity used while a send is pending.
  final String localId;

  /// Authoritative server identity, when confirmed.
  final int? serverId;

  /// Message direction.
  final WisperBotMessageRole role;

  /// Content category.
  final WisperBotMessageType type;

  /// Plain-text body or caption.
  final String body;

  /// Current delivery state.
  final WisperBotMessageStatus status;

  /// Message creation time.
  final DateTime createdAt;

  /// Optional attachment metadata.
  final WisperBotAttachment? attachment;

  /// Images supplied by the backend for this lookup reply.
  final List<WisperBotLookupImage> lookupImages;

  /// Optional in-memory upload used for local pending media previews.
  final WisperBotUpload? localUpload;

  /// Whether this entry is a public conversation activity.
  final bool isActivity;

  /// Optional backend-supplied sender name.
  final String? senderName;

  /// Optional backend-supplied sender category.
  final WisperBotSenderKind? sentBy;

  /// Safe delivery failure, when applicable.
  final WisperBotException? error;

  /// Whether the message has been read or seen.
  bool get isSeen => status == WisperBotMessageStatus.read;

  /// Alias for [isSeen].
  bool get isRead => isSeen;

  /// Whether the message has been delivered to the recipient.
  bool get isDelivered => status == WisperBotMessageStatus.delivered || isSeen;

  /// Returns an updated immutable message.
  WisperBotMessage copyWith({
    String? localId,
    int? serverId,
    WisperBotMessageRole? role,
    WisperBotMessageType? type,
    String? body,
    WisperBotMessageStatus? status,
    DateTime? createdAt,
    WisperBotAttachment? attachment,
    List<WisperBotLookupImage>? lookupImages,
    WisperBotUpload? localUpload,
    String? senderName,
    bool? isActivity,
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
        lookupImages: lookupImages ?? this.lookupImages,
        localUpload: localUpload ?? this.localUpload,
        senderName: senderName ?? this.senderName,
        isActivity: isActivity ?? this.isActivity,
        sentBy: sentBy ?? this.sentBy,
        error: clearError ? null : error ?? this.error,
      );
}
