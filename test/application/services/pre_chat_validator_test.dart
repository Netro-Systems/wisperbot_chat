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
