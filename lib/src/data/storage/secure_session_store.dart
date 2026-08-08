import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../domain/contracts/session_store.dart';

/// Default session store backed by platform-protected secure storage.
class FlutterSecureWisperBotSessionStore implements WisperBotSessionStore {
  /// Creates a secure store, optionally using an injected storage adapter.
  FlutterSecureWisperBotSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

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
  ) =>
      _storage.write(
        key: namespace,
        value: jsonEncode(<String, Object>{
          'visitor_id': session.visitorId,
          'token': session.token,
          'saved_at': session.savedAt.toUtc().toIso8601String(),
          'pre_chat_completed': session.preChatCompleted,
          'schema_version': session.schemaVersion,
        }),
      );

  @override
  Future<void> delete(String namespace) => _storage.delete(key: namespace);
}
