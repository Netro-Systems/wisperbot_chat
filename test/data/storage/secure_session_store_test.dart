import 'dart:convert';

import 'package:flutter/services.dart';
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

  for (final failingKey in [namespace, 'wisperbot_chat_session_index_v1']) {
    test('recovers a duplicate Keychain item for $failingKey', () async {
      final adapter = _FailingStorage(failingKey, -25299);
      final store = FlutterSecureWisperBotSessionStore(storage: adapter);
      await store.write(
          namespace,
          WisperBotStoredSession(
            visitorId: 'visitor-1',
            token: 'token',
            savedAt: DateTime.utc(2026),
          ));
      expect((await store.read(namespace))?.token, 'token');
      expect(adapter.deletedKeys, [failingKey]);
    });
  }

  test('does not delete credentials for other storage errors', () async {
    final adapter = _FailingStorage(namespace, -34018);
    final store = FlutterSecureWisperBotSessionStore(storage: adapter);
    await expectLater(
        store.write(
            namespace,
            WisperBotStoredSession(
              visitorId: 'visitor-1',
              token: 'token',
              savedAt: DateTime.utc(2026),
            )),
        throwsA(isA<PlatformException>()));
    expect(adapter.deletedKeys, isEmpty);
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

  test('keeps only the fifteen newest secure sessions', () async {
    final store = FlutterSecureWisperBotSessionStore(storage: storage);

    for (var index = 0; index < 16; index++) {
      await store.write(
        'wisperbot.test.session.$index',
        WisperBotStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 8, 12, index),
        ),
      );
    }

    expect(await store.read('wisperbot.test.session.0'), isNull);
    expect(await store.read('wisperbot.test.session.1'), isNotNull);
    expect(await store.read('wisperbot.test.session.15'), isNotNull);
  });

  test('rewriting an old session keeps it inside the fifteen-session limit',
      () async {
    final store = FlutterSecureWisperBotSessionStore(storage: storage);

    for (var index = 0; index < 15; index++) {
      await store.write(
        'wisperbot.test.session.$index',
        WisperBotStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 8, 12, index),
        ),
      );
    }
    await store.write(
      'wisperbot.test.session.0',
      WisperBotStoredSession(
        visitorId: 'visitor-0-new',
        token: 'token-0-new',
        savedAt: DateTime.utc(2026, 8, 8, 13),
      ),
    );
    await store.write(
      'wisperbot.test.session.15',
      WisperBotStoredSession(
        visitorId: 'visitor-15',
        token: 'token-15',
        savedAt: DateTime.utc(2026, 8, 8, 14),
      ),
    );

    final rewritten = await store.read('wisperbot.test.session.0');
    expect(rewritten?.visitorId, 'visitor-0-new');
    expect(await store.read('wisperbot.test.session.1'), isNull);
    expect(await store.read('wisperbot.test.session.15'), isNotNull);
  });

  test('delete removes a secure session from the pruning index', () async {
    final store = FlutterSecureWisperBotSessionStore(storage: storage);

    await store.write(
      namespace,
      WisperBotStoredSession(
        visitorId: 'visitor-1',
        token: 'token-1',
        savedAt: DateTime.utc(2026, 8, 8),
      ),
    );
    await store.delete(namespace);

    for (var index = 0; index < 15; index++) {
      await store.write(
        'wisperbot.test.session.$index',
        WisperBotStoredSession(
          visitorId: 'visitor-$index',
          token: 'token-$index',
          savedAt: DateTime.utc(2026, 8, 9, 12, index),
        ),
      );
    }

    expect(await store.read(namespace), isNull);
    expect(await store.read('wisperbot.test.session.0'), isNotNull);
  });
}

class _FailingStorage extends FlutterSecureStorage {
  _FailingStorage(this.failingKey, this.status);
  final String failingKey;
  final int status;
  bool failed = false;
  final deletedKeys = <String>[];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (key == failingKey && !failed) {
      failed = true;
      throw PlatformException(
          code: 'Unexpected security result code', details: status);
    }
    await super.write(key: key, value: value);
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    deletedKeys.add(key);
    await super.delete(key: key);
  }
}
