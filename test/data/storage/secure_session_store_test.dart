import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/data/storage/secure_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const namespace = 'wisperbot.test.session';
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('round trips versioned session credentials', () async {
    final store = FlutterSecureWisperBotSessionStore(storage: storage);
    final session = WisperBotStoredSession(
      visitorId: 'visitor-1',
      token: 'secret-token',
      savedAt: DateTime.utc(2026, 8, 8),
      preChatCompleted: true,
    );

    await store.write(namespace, session);
    final restored = await store.read(namespace);

    expect(restored?.visitorId, session.visitorId);
    expect(restored?.token, session.token);
    expect(restored?.preChatCompleted, isTrue);
    expect(restored?.schemaVersion, 1);
  });

  test('malformed or obsolete records are deleted during restoration',
      () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      namespace: jsonEncode(<String, Object>{
        'visitor_id': 'visitor-1',
        'token': 'secret-token',
        'saved_at': 'not-a-date',
        'schema_version': 1,
      }),
    });
    final store = FlutterSecureWisperBotSessionStore(storage: storage);

    expect(await store.read(namespace), isNull);
    expect(await storage.read(key: namespace), isNull);
  });
}
