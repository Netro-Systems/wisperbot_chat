import 'package:flutter/foundation.dart';

import 'config.dart';
import 'models.dart';

@immutable
sealed class WisperBotChatEvent {
  const WisperBotChatEvent();
}

final class WisperBotSessionReady extends WisperBotChatEvent {
  const WisperBotSessionReady({required this.identity});

  final WisperBotIdentityStatus identity;
}

final class WisperBotChatOpened extends WisperBotChatEvent {
  const WisperBotChatOpened();
}

final class WisperBotChatClosed extends WisperBotChatEvent {
  const WisperBotChatClosed({required this.reason});

  final WisperBotChatCloseReason reason;
}

final class WisperBotMessageSent extends WisperBotChatEvent {
  const WisperBotMessageSent({required this.message});

  final WisperBotMessage message;
}

final class WisperBotMessageReceived extends WisperBotChatEvent {
  const WisperBotMessageReceived({required this.message});

  final WisperBotMessage message;
}

final class WisperBotHandoffChanged extends WisperBotChatEvent {
  const WisperBotHandoffChanged({required this.handoff});

  final WisperBotHandoffState handoff;
}

final class WisperBotUnreadChanged extends WisperBotChatEvent {
  const WisperBotUnreadChanged({required this.unreadCount});

  final int unreadCount;
}

final class WisperBotConnectionChanged extends WisperBotChatEvent {
  const WisperBotConnectionChanged({required this.connection});

  final WisperBotConnectionState connection;
}
