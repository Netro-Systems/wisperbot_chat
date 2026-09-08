import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';
import 'package:wisperbot_chat/src/application/services/message_reconciler.dart';

void main() {
  const reconciler = MessageReconciler();

  test('deduplicates by server ID and preserves the existing local ID', () {
    final upload = WisperBotUpload(
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      filename: 'local.png',
      mimeType: 'image/png',
    );
    final existing = _message(
      localId: 'pending-1',
      serverId: 4,
      body: 'old',
      localUpload: upload,
    );
    final replacement = _message(
      localId: 'server-4',
      serverId: 4,
      body: 'authoritative',
    );

    final result = reconciler.merge(<WisperBotMessage>[existing], <WisperBotMessage>[replacement]);

    expect(result, hasLength(1));
    expect(result.single.localId, 'pending-1');
    expect(result.single.localUpload?.filename, 'local.png');
    expect(result.single.body, 'authoritative');
  });

  test('orders server messages before pending local messages', () {
    final result = reconciler.merge(
      <WisperBotMessage>[_message(localId: 'pending', serverId: null)],
      <WisperBotMessage>[
        _message(localId: 'two', serverId: 2),
        _message(localId: 'one', serverId: 1),
      ],
    );

    expect(result.map((message) => message.localId), <String>['one', 'two', 'pending']);
    expect(reconciler.greatestServerId(result, fallback: 0), 2);
  });
}

WisperBotMessage _message({
  required String localId,
  required int? serverId,
  String body = 'message',
  WisperBotUpload? localUpload,
}) =>
    WisperBotMessage(
      localId: localId,
      serverId: serverId,
      role: WisperBotMessageRole.agent,
      type: WisperBotMessageType.text,
      body: body,
      status: WisperBotMessageStatus.sent,
      createdAt: DateTime.utc(2026, 8, 6),
      localUpload: localUpload,
    );
