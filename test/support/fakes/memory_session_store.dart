import 'package:wisperbot_chat/wisperbot_chat.dart';

/// In-memory credential store that records persistence interactions.
final class MemorySessionStore implements WisperBotSessionStore {
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
