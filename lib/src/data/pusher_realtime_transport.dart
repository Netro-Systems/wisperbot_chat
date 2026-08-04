import 'dart:convert';

import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../domain/realtime.dart';

class PusherWisperBotRealtimeTransport implements WisperBotRealtimeTransport {
  final PusherChannelsFlutter _pusher = PusherChannelsFlutter.getInstance();

  @override
  Future<WisperBotRealtimeConnection> connect({
    required WisperBotRealtimeSettings settings,
    required WisperBotRealtimeAuthorizer authorize,
    required void Function(WisperBotRealtimeEvent event) onEvent,
    required void Function(WisperBotRealtimeStatus status) onStatus,
  }) async {
    onStatus(WisperBotRealtimeStatus.connecting);
    await _pusher.init(
      apiKey: settings.apiKey,
      cluster: settings.cluster,
      useTLS: true,
      onAuthorizer: (channelName, socketId, _) async {
        final result = await authorize(socketId, channelName);
        return <String, String>{'auth': result.auth};
      },
      onConnectionStateChange: (current, _) {
        if (current == 'DISCONNECTED' || current == 'UNAVAILABLE') {
          onStatus(WisperBotRealtimeStatus.reconnecting);
        }
      },
      onSubscriptionError: (_, __) {
        onStatus(WisperBotRealtimeStatus.unavailable);
      },
      onError: (_, __, ___) {
        onStatus(WisperBotRealtimeStatus.reconnecting);
      },
    );
    await _pusher.subscribe(
      channelName: settings.channel,
      onSubscriptionSucceeded: (_) {
        onStatus(WisperBotRealtimeStatus.connected);
      },
      onEvent: (dynamic raw) {
        if (raw is! PusherEvent || raw.eventName != 'WidgetMessageSent') return;
        final data =
            raw.data is String ? raw.data as String : jsonEncode(raw.data);
        onEvent(WisperBotRealtimeEvent(name: raw.eventName, data: data));
      },
    );
    await _pusher.connect();
    return _PusherRealtimeConnection(_pusher, settings.channel);
  }
}

class _PusherRealtimeConnection implements WisperBotRealtimeConnection {
  _PusherRealtimeConnection(this._pusher, this._channel);
  final PusherChannelsFlutter _pusher;
  final String _channel;
  bool _closed = false;

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pusher.unsubscribe(channelName: _channel);
    await _pusher.disconnect();
  }
}
