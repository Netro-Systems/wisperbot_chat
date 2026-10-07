import '../../domain/models/models.dart';

/// Pure ordering and server-ID reconciliation for immutable message lists.
///
/// Server IDs are authoritative. Local IDs remain attached when a later
/// server representation replaces an existing entry.
final class MessageReconciler {
  const MessageReconciler();

  List<WisperBotMessage> merge(
    List<WisperBotMessage> existing,
    List<WisperBotMessage> incoming, {
    void Function(WisperBotMessage message)? onNewAgentMessage,
  }) {
    final messages = <WisperBotMessage>[...existing];
    final indexes = <int, int>{};
    for (var index = 0; index < messages.length; index++) {
      final id = messages[index].serverId;
      if (id != null) indexes[id] = index;
    }
    for (final message in incoming) {
      final id = message.serverId;
      if (id == null) continue;
      final existingIndex = indexes[id];
      if (existingIndex == null) {
        indexes[id] = messages.length;
        messages.add(message);
        if (message.role == WisperBotMessageRole.agent && !message.isActivity) {
          onNewAgentMessage?.call(message);
        }
      } else {
        final existingMessage = messages[existingIndex];
        messages[existingIndex] = message.copyWith(
          localId: existingMessage.localId,
          localUpload: existingMessage.localUpload,
          status: _mostAdvancedStatus(
            existingMessage.status,
            message.status,
          ),
        );
      }
    }
    messages.sort(compare);
    return messages;
  }

  int compare(WisperBotMessage a, WisperBotMessage b) {
    final aId = a.serverId;
    final bId = b.serverId;
    if (aId != null && bId != null) return aId.compareTo(bId);
    if (aId != null) return -1;
    if (bId != null) return 1;
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.localId.compareTo(b.localId);
  }

  WisperBotMessageStatus _mostAdvancedStatus(
    WisperBotMessageStatus current,
    WisperBotMessageStatus incoming,
  ) {
    if (current == incoming) return current;
    if (incoming == WisperBotMessageStatus.failed) {
      return current == WisperBotMessageStatus.delivered ||
              current == WisperBotMessageStatus.read
          ? current
          : incoming;
    }
    if (current == WisperBotMessageStatus.failed) return current;
    const rank = <WisperBotMessageStatus, int>{
      WisperBotMessageStatus.pending: 0,
      WisperBotMessageStatus.unconfirmed: 0,
      WisperBotMessageStatus.sent: 1,
      WisperBotMessageStatus.delivered: 2,
      WisperBotMessageStatus.read: 3,
      WisperBotMessageStatus.failed: -1,
    };
    return rank[incoming]! > rank[current]! ? incoming : current;
  }
}
