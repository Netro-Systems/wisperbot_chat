import 'package:flutter/foundation.dart';

enum WisperBotRealtimeStatus {
  disabled,
  connecting,
  connected,
  reconnecting,
  unavailable,
}

@immutable
class WisperBotRealtimeSettings {
  const WisperBotRealtimeSettings({
    required this.apiKey,
    required this.cluster,
    required this.channel,
    required this.authEndpoint,
  });

  final String apiKey;
  final String cluster;
  final String channel;
  final Uri authEndpoint;
}

@immutable
class WisperBotRealtimeAuthorization {
  const WisperBotRealtimeAuthorization({required this.auth});
  final String auth;
}

@immutable
class WisperBotRealtimeEvent {
  const WisperBotRealtimeEvent({required this.name, required this.data});
  final String name;
  final String data;
}

typedef WisperBotRealtimeAuthorizer = Future<WisperBotRealtimeAuthorization>
    Function(String socketId, String channelName);

abstract interface class WisperBotRealtimeConnection {
  Future<void> close();
}

abstract interface class WisperBotRealtimeTransport {
  Future<WisperBotRealtimeConnection> connect({
    required WisperBotRealtimeSettings settings,
    required WisperBotRealtimeAuthorizer authorize,
    required void Function(WisperBotRealtimeEvent event) onEvent,
    required void Function(WisperBotRealtimeStatus status) onStatus,
  });
}
