import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void main() {
  test('public barrel exposes the supported headless integration', () {
    const config = WisperBotConfig(widgetKey: 'public-widget-key');
    final client = WisperBotClient(
      config: config,
      sessionStore: _NoopSessionStore(),
    );
    final controller = WisperBotChatController(client: client);

    expect(controller.config, same(config));
    expect(config.oneSignalAppId, WisperBotConfig.defaultOneSignalAppId);
    expect(config.enableOneSignal, isTrue);
    expect(WidgetOneSignalService.instance, isNotNull);

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
