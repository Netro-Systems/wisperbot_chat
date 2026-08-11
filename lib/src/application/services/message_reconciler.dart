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
        if (message.role == WisperBotMessageRole.agent) {
          onNewAgentMessage?.call(message);
        }
      } else {
        messages[existingIndex] = message.copyWith(
          localId: messages[existingIndex].localId,
          localUpload: messages[existingIndex].localUpload,
        );
      }
    }
    messages.sort(compare);
    return messages;
  }

  int greatestServerId(
    List<WisperBotMessage> messages, {
    required int fallback,
  }) =>
      messages.fold<int>(
        fallback,
        (greatest, message) => message.serverId == null
            ? greatest
            : greatest > message.serverId!
                ? greatest
                : message.serverId!,
      );

  int compare(WisperBotMessage a, WisperBotMessage b) {
    final aId = a.serverId;
    final bId = b.serverId;
    if (aId != null && bId != null) return aId.compareTo(bId);
    if (aId != null) return -1;
    if (bId != null) return 1;
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.localId.compareTo(b.localId);
  }
}
