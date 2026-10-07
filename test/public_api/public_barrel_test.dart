import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void main() {
  test('public barrel exposes the supported headless integration', () {
    final client = WisperBotClient(
      widgetKey: 'public-widget-key',
      oneSignalAppId: 'custom-onesignal-app-id',
      sessionStore: _NoopSessionStore(),
    );
    final controller = WisperBotChatController(client: client);

    expect(controller.user, isNull);
    expect(WisperBotChat.launcher(), isA<WisperBotChatLauncher>());
    expect(WisperBotChat.view(), isA<WisperBotChatView>());
    expect(WisperBotChat.screen(), isA<WisperBotChatScreen>());
    const starter = WisperBotStarterQuestion(
      id: 'sq_public',
      label: 'What are your opening hours?',
    );
    expect(starter.id, 'sq_public');
    expect(starter.label, 'What are your opening hours?');

    controller.dispose();
    client.close();
  });
}

final class _NoopSessionStore implements WisperBotSessionStore {
  @override
  Future<void> delete(String namespace) async {}

  @override
  Future<WisperBotStoredSession?> read(String namespace) async => null;

  @override
  Future<void> write(
    String namespace,
    WisperBotStoredSession session,
  ) async {}
}
