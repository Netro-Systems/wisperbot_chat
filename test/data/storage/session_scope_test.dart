import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
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

  test('sessions are isolated by widget, base URL, and signed identity', () {
    const signatureA =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const signatureB =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const userA = WisperBotUser(
      externalId: 'customer-top-secret-a',
      signature: signatureA,
    );
    const userB = WisperBotUser(
      externalId: 'customer-top-secret-b',
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

  test('unsigned profiles require an ephemeral namespace scope', () {
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

    expect(first, isNot(second));
  });

  test('unsigned profiles with stable identity reuse a local namespace', () {
    const externalUser = WisperBotUser(
      externalId: 'customer-123',
      name: 'Customer One',
    );
    const emailUser = WisperBotUser(email: 'customer@example.com');

    final externalFirst = sessionNamespace(
      config: base,
      user: externalUser,
      unsignedEphemeralScope: 'scope-one',
    );
    final externalSecond = sessionNamespace(
      config: base,
      user: externalUser,
      unsignedEphemeralScope: 'scope-two',
    );
    final emailScope = sessionNamespace(config: base, user: emailUser);

    expect(externalFirst, externalSecond);
    expect(externalFirst, isNot(emailScope));
    expect(externalFirst, isNot(contains('customer-123')));
    expect(emailScope, isNot(contains('customer@example.com')));
  });

  test('configuration rejects unsafe identity and polling values', () {
    expect(
      () => WisperBotClient(
        config: const WisperBotConfig(widgetKey: ''),
      ),
      throwsA(isA<WisperBotException>()),
    );
    expect(
      () => WisperBotClient(
        config: const WisperBotConfig(
          widgetKey: 'key',
          user: WisperBotUser(externalId: ' padded '),
        ),
      ),
      throwsA(isA<WisperBotException>()),
    );
    expect(
      () => WisperBotClient(
        config: const WisperBotConfig(
          widgetKey: 'key',
          polling: WisperBotPollingConfig(visibleInterval: Duration.zero),
        ),
      ),
      throwsA(isA<WisperBotException>()),
    );
  });

  test('public models redact credentials from string representations', () {
    const user = WisperBotUser(
      externalId: 'customer-secret',
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
