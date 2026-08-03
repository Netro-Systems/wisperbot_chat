import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@immutable
class WisperBotStoredSession {
  const WisperBotStoredSession({
    required this.visitorId,
    required this.token,
    required this.savedAt,
    this.schemaVersion = 1,
  });

  final String visitorId;
  final String token;
  final DateTime savedAt;
  final int schemaVersion;

  @override
  String toString() =>
      'WisperBotStoredSession(visitorId: [redacted], token: [redacted], '
      'savedAt: $savedAt, schemaVersion: $schemaVersion)';
}

abstract interface class WisperBotSessionStore {
  Future<WisperBotStoredSession?> read(String namespace);

  Future<void> write(String namespace, WisperBotStoredSession session);

  Future<void> delete(String namespace);
}

class FlutterSecureWisperBotSessionStore implements WisperBotSessionStore {
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
      final schemaVersion = value['schema_version'];
      if (visitorId is! String ||
          visitorId.isEmpty ||
          token is! String ||
          token.isEmpty ||
          savedAt is! String ||
          schemaVersion is! int ||
          schemaVersion != 1) {
        throw const FormatException('Session record is incomplete.');
      }
      return WisperBotStoredSession(
        visitorId: visitorId,
        token: token,
        savedAt: DateTime.parse(savedAt).toUtc(),
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
          'schema_version': session.schemaVersion,
        }),
      );

  @override
  Future<void> delete(String namespace) => _storage.delete(key: namespace);
}
