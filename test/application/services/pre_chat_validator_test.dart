import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/pre_chat_validator.dart';

void main() {
  const validator = PreChatValidator();

  test('accepts required values supplied by the active user', () {
    expect(
      validator.isSatisfiedBy(
        _widget(<WisperBotPreChatField>[
          WisperBotPreChatField.name,
          WisperBotPreChatField.email,
        ]),
        const WisperBotUser(name: 'Visitor', email: 'visitor@example.com'),
      ),
      isTrue,
    );
  });

  test('validates submission using user fallback for existing fields', () {
    final widget = _widget(<WisperBotPreChatField>[
      WisperBotPreChatField.name,
      WisperBotPreChatField.email,
    ]);

    // Name is in user, email is in data -> valid
    expect(
      () => validator.validateSubmission(
        widget,
        const WisperBotPreChatData(email: 'visitor@example.com'),
        user: const WisperBotUser(name: 'Visitor'),
      ),
      returnsNormally,
    );

    // Name is missing in both data and user -> throws validation exception
    expect(
      () => validator.validateSubmission(
        widget,
        const WisperBotPreChatData(email: 'visitor@example.com'),
        user: null,
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.validation,
        ),
      ),
    );
  });

  test('rejects unknown backend requirements as unsupported', () {
    expect(
      () => validator.validateConfiguration(
        _widget(<WisperBotPreChatField>[WisperBotPreChatField.unknown]),
      ),
      throwsA(
        isA<WisperBotException>().having(
          (error) => error.code,
          'code',
          WisperBotErrorCode.unsupported,
        ),
      ),
    );
  });
}

WisperBotWidgetConfig _widget(List<WisperBotPreChatField> fields) =>
    WisperBotWidgetConfig(
      title: 'Support',
      subtitle: 'Online',
      welcomeMessage: 'Hello',
      agentName: 'Support',
      primaryColorHex: '#ff762e',
      launcherPosition: WisperBotLauncherPosition.bottomRight,
      footerCompanyName: 'WisperBot',
      teamMembers: const <WisperBotTeamMember>[],
      aiEnabled: true,
      requiresPreChat: true,
      preChatFields: fields,
    );
