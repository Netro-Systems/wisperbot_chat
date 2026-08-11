import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts/session_store.dart';

/// Default session store backed by platform-protected secure storage.
class FlutterSecureWisperBotSessionStore implements WisperBotSessionStore {
  /// Creates a secure store, optionally using an injected storage adapter.
  FlutterSecureWisperBotSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const int _maxStoredSessions = 15;
  static const String _indexKey = 'wisperbot_chat_session_index_v1';

  @override
  Future<WisperBotStoredSession?> read(String namespace) async {
    final encoded = await _storage.read(key: namespace);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final value = jsonDecode(encoded);
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Session record is not an object.');
      }
      final visitorId = value['visitor_id'];
      final token = value['token'];
      final savedAt = value['saved_at'];
      final preChatCompleted = value['pre_chat_completed'];
      final schemaVersion = value['schema_version'];
      if (visitorId is! String ||
          visitorId.isEmpty ||
          token is! String ||
          token.isEmpty ||
          savedAt is! String ||
          (preChatCompleted != null && preChatCompleted is! bool) ||
          schemaVersion is! int ||
          schemaVersion != 1) {
        throw const FormatException('Session record is incomplete.');
      }
      return WisperBotStoredSession(
        visitorId: visitorId,
        token: token,
        savedAt: DateTime.parse(savedAt).toUtc(),
        preChatCompleted: preChatCompleted == true,
        schemaVersion: schemaVersion,
      );
    } on Object {
      await delete(namespace);
      return null;
    }
  }

  @override
  Future<void> write(
    String namespace,
    WisperBotStoredSession session,
  ) async {
    await _storage.write(
      key: namespace,
      value: jsonEncode(<String, Object>{
        'visitor_id': session.visitorId,
        'token': session.token,
        'saved_at': session.savedAt.toUtc().toIso8601String(),
        'pre_chat_completed': session.preChatCompleted,
        'schema_version': session.schemaVersion,
      }),
    );
    await _recordSessionWrite(namespace, session.savedAt);
  }

  @override
  Future<void> delete(String namespace) async {
    await _storage.delete(key: namespace);
    await _removeFromIndex(namespace);
  }

  Future<void> _recordSessionWrite(String namespace, DateTime savedAt) async {
    final entries = await _readIndex();
    entries.removeWhere((entry) => entry.namespace == namespace);
    entries.add(_SessionIndexEntry(namespace, savedAt.toUtc()));
    entries.sort((a, b) => a.savedAt.compareTo(b.savedAt));

    while (entries.length > _maxStoredSessions) {
      final removeIndex = entries.indexWhere(
        (entry) => entry.namespace != namespace,
      );
      if (removeIndex < 0) {
        break;
      }
      final removed = entries.removeAt(removeIndex);
      await _storage.delete(key: removed.namespace);
    }

    await _writeIndex(entries);
  }

  Future<void> _removeFromIndex(String namespace) async {
    final entries = await _readIndex();
    final originalLength = entries.length;
    entries.removeWhere((entry) => entry.namespace == namespace);
    if (entries.length != originalLength) {
      await _writeIndex(entries);
    }
  }

  Future<List<_SessionIndexEntry>> _readIndex() async {
    final encoded = await _storage.read(key: _indexKey);
    if (encoded == null || encoded.isEmpty) {
      return <_SessionIndexEntry>[];
    }
    try {
      final value = jsonDecode(encoded);
      if (value is! List<dynamic>) {
        throw const FormatException('Session index is not a list.');
      }
      final entries = <_SessionIndexEntry>[];
      for (final item in value) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Session index item is not an object.');
        }
        final namespace = item['namespace'];
        final savedAt = item['saved_at'];
        if (namespace is! String ||
            namespace.isEmpty ||
            namespace == _indexKey ||
            savedAt is! String) {
          throw const FormatException('Session index item is incomplete.');
        }
        entries.add(
          _SessionIndexEntry(namespace, DateTime.parse(savedAt).toUtc()),
        );
      }
      return entries;
    } on Object {
      await _storage.delete(key: _indexKey);
      return <_SessionIndexEntry>[];
    }
  }

  Future<void> _writeIndex(List<_SessionIndexEntry> entries) {
    return _storage.write(
      key: _indexKey,
      value: jsonEncode(
        entries
            .map(
              (entry) => <String, Object>{
                'namespace': entry.namespace,
                'saved_at': entry.savedAt.toUtc().toIso8601String(),
              },
            )
            .toList(growable: false),
      ),
    );
  }
}

final class _SessionIndexEntry {
  const _SessionIndexEntry(this.namespace, this.savedAt);

  final String namespace;
  final DateTime savedAt;
}
