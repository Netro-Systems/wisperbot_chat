import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/state/chat_state_machine.dart';

void main() {
  test('owns and replaces immutable controller snapshots', () {
    final machine = ChatStateMachine();
    expect(machine.state.phase, WisperBotChatPhase.idle);

    final ready = machine.state.copyWith(phase: WisperBotChatPhase.ready);
    machine.replace(ready);

    expect(machine.state, same(ready));
  });
}
