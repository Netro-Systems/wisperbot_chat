import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/configuration/wisperbot_config.dart';
import 'package:wisperbot_chat/src/data/storage/session_scope.dart';

void main() {
  const base = WisperBotConfig(
    widgetKey: 'widget-a',
    apiBaseUrl: 'https://CHAT.example.com:443/api/',
  );

  test('canonical base URLs share an anonymous secure-storage namespace', () {
    const equivalent = WisperBotConfig(
      widgetKey: 'widget-a',
      apiBaseUrl: 'https://chat.example.com/api',
    );

    expect(
      sessionNamespace(config: base, user: null),
      sessionNamespace(config: equivalent, user: null),
    );
  });

  test('empty user shares the anonymous secure-storage namespace', () {
    expect(
      sessionNamespace(config: base, user: const WisperBotUser()),
      sessionNamespace(config: base, user: null),
    );
  });

  test('sessions are isolated by widget, base URL, and user ID', () {
    const signatureA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const signatureB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const userA = WisperBotUser(
      userId: 'customer-top-secret-a',
      signature: signatureA,
    );
    const userB = WisperBotUser(
      userId: 'customer-top-secret-b',
      signature: signatureB,
    );

    final anonymous = sessionNamespace(config: base, user: null);
    final signedA = sessionNamespace(config: base, user: userA);
    final signedB = sessionNamespace(config: base, user: userB);
    final otherWidget = sessionNamespace(
      config: const WisperBotConfig(
        widgetKey: 'widget-b',
        apiBaseUrl: 'https://chat.example.com/api',
      ),
      user: userA,
    );
    final otherHost = sessionNamespace(
      config: const WisperBotConfig(
        widgetKey: 'widget-a',
        apiBaseUrl: 'https://other.example.com/api',
      ),
      user: userA,
    );

    expect(<String>{anonymous, signedA, signedB, otherWidget, otherHost},
        hasLength(5));
    expect(signedA, isNot(contains('customer-top-secret-a')));
    expect(signedA, isNot(contains(signatureA)));
  });

  test('name-only profiles share the installation guest namespace', () {
    const user = WisperBotUser(name: 'Display only');
    final first = sessionNamespace(
      config: base,
      user: user,
      unsignedEphemeralScope: 'scope-one',
    );
    final second = sessionNamespace(
      config: base,
      user: user,
      unsignedEphemeralScope: 'scope-two',
    );

    expect(first, second);
    expect(first, sessionNamespace(config: base, user: null));
  });

  test('user IDs reuse an account namespace while email remains guest data',
      () {
    const identifiedUser = WisperBotUser(
      userId: 'customer-123',
      name: 'Customer One',
    );
    const emailUser = WisperBotUser(email: 'customer@example.com');

    final externalFirst = sessionNamespace(
      config: base,
      user: identifiedUser,
      unsignedEphemeralScope: 'scope-one',
    );
    final externalSecond = sessionNamespace(
      config: base,
      user: identifiedUser,
      unsignedEphemeralScope: 'scope-two',
    );
    final emailScope = sessionNamespace(config: base, user: emailUser);

    expect(externalFirst, externalSecond);
    expect(externalFirst, isNot(emailScope));
    expect(externalFirst, isNot(contains('customer-123')));
    expect(emailScope, sessionNamespace(config: base, user: null));
  });

  test('legacy account namespace remains discoverable for one-time migration',
      () {
    const user = WisperBotUser(userId: 'customer-123');
    final current = sessionNamespace(config: base, user: user);
    final legacy = legacyAccountSessionNamespace(config: base, user: user);

    expect(legacy, isNotNull);
    expect(legacy, isNot(current));
    expect(legacy, isNot(contains('customer-123')));
  });

  test('userId and externalId aliases resolve to the same account scope', () {
    expect(
      sessionNamespace(
        config: base,
        user: const WisperBotUser(userId: 'customer-123'),
      ),
      sessionNamespace(
        config: base,
        user: const WisperBotUser(externalId: 'customer-123'),
      ),
    );
  });

  test('configuration rejects unsafe identity values', () {
    expect(
      () => WisperBotClient.fromConfig(
        config: const WisperBotConfig(widgetKey: ''),
      ),
      throwsA(isA<WisperBotException>()),
    );
    expect(
      () => WisperBotClient.fromConfig(
        config: const WisperBotConfig(widgetKey: 'key'),
        user: const WisperBotUser(userId: ' padded '),
      ),
      throwsA(isA<WisperBotException>()),
    );
    expect(
      () => WisperBotClient.fromConfig(
        config: const WisperBotConfig(widgetKey: 'key'),
        user: const WisperBotUser(
          userId: 'customer-1',
          externalId: 'customer-2',
        ),
      ),
      throwsA(isA<WisperBotException>()),
    );
  });

  test('public models redact credentials from string representations', () {
    const user = WisperBotUser(
      userId: 'customer-secret',
      email: 'secret@example.com',
      signature: 'signature-secret',
    );
    final stored = WisperBotStoredSession(
      visitorId: 'visitor-secret',
      token: 'token-secret',
      savedAt: DateTime.utc(2026),
    );

    expect(user.toString(), isNot(contains('customer-secret')));
    expect(user.toString(), isNot(contains('secret@example.com')));
    expect(stored.toString(), isNot(contains('token-secret')));
    expect(stored.toString(), isNot(contains('visitor-secret')));
  });
}
