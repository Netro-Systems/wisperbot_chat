import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists failed WisperBot revocations without exposing bearer tokens in prefs.
final class PushRevocationStore {
  PushRevocationStore(String apiBaseUrl, String widgetKey)
      : _key =
            'wisperbot_push_revocations_${sha256.convert(utf8.encode('$apiBaseUrl|$widgetKey'))}';

  final String _key;
  static const _storage = FlutterSecureStorage();

  Future<List<Map<String, String>>> read() async {
    final value = await _storage.read(key: _key);
    if (value == null) return [];
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded
        .map((entry) => Map<String, String>.from(entry as Map))
        .toList();
  }

  Future<void> write(List<Map<String, String>> entries) async {
    if (entries.isEmpty) {
      await _storage.delete(key: _key);
    } else {
      await _storage.write(key: _key, value: jsonEncode(entries));
    }
  }
}
