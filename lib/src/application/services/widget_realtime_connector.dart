import 'dart:async';
import 'dart:convert';

import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/models.dart';

typedef WidgetRealtimePayloadCallback = void Function(Object? payload);
typedef WidgetRealtimeErrorCallback = void Function(
  Object error,
  StackTrace trace,
);

abstract interface class WidgetRealtimeConnector {
  Future<void> start({
    required WisperBotRealtimeConfig config,
    required String widgetKey,
    required String token,
    required int conversationId,
    void Function()? onConnected,
    WidgetRealtimePayloadCallback? onMessageCreated,
    WidgetRealtimePayloadCallback? onTypingChanged,
    WidgetRealtimePayloadCallback? onHandoffUpdated,
    WidgetRealtimeErrorCallback? onError,
  });

  Future<void> stop();
}

final class PusherWidgetRealtimeConnector implements WidgetRealtimeConnector {
  PusherWidgetRealtimeConnector({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final List<StreamSubscription<dynamic>> _subscriptions = <StreamSubscription<dynamic>>[];

  PusherChannelsClient? _client;
  PrivateChannel? _channel;
  String? _activeSignature;

  @override
  Future<void> start({
    required WisperBotRealtimeConfig config,
    required String widgetKey,
    required String token,
    required int conversationId,
    void Function()? onConnected,
    WidgetRealtimePayloadCallback? onMessageCreated,
    WidgetRealtimePayloadCallback? onTypingChanged,
    WidgetRealtimePayloadCallback? onHandoffUpdated,
    WidgetRealtimeErrorCallback? onError,
  }) async {
    final signature = '${config.key}|${config.cluster}|$widgetKey|$conversationId|$token';
    if (_activeSignature == signature && _client != null) return;

    await stop();

    if (!config.isEnabled) return;

    final client = PusherChannelsClient.websocket(
      options: PusherChannelsOptions.fromCluster(
        scheme: 'wss',
        cluster: config.cluster,
        key: config.key,
        port: 443,
        shouldSupplyMetadataQueries: true,
        metadata: PusherChannelsOptionsMetadata.byDefault(),
      ),
      connectionErrorHandler: (exception, trace, refresh) async {
        onError?.call(exception, trace);
        refresh();
      },
    );
    final channelName = 'private-widget-conversation.$conversationId';
    final channel = client.privateChannel(
      channelName,
      authorizationDelegate: _WidgetPrivateChannelAuthorizationDelegate(
        httpClient: _httpClient,
        authorizationEndpoint: config.authEndpoint,
        widgetKey: widgetKey,
        token: token,
      ),
    );

    _subscriptions.add(
      client.onConnectionEstablished.listen((_) {
        channel.subscribeIfNotUnsubscribed();
        onConnected?.call();
      }),
    );
    _subscriptions.add(
      channel.bind('WidgetMessageCreated').listen((event) {
        onMessageCreated?.call(event.tryGetDataAsMap());
      }),
    );
    _subscriptions.add(
      channel.bind('WidgetTypingChanged').listen((event) {
        onTypingChanged?.call(event.tryGetDataAsMap());
      }),
    );
    _subscriptions.add(
      channel.bind('WidgetHandoffUpdated').listen((event) {
        onHandoffUpdated?.call(event.tryGetDataAsMap());
      }),
    );
    _subscriptions.add(
      channel.onAuthenticationSubscriptionFailed().listen((event) {
        onError?.call(
          StateError('Widget realtime authorization failed: ${event.data}'),
          StackTrace.current,
        );
      }),
    );
    _subscriptions.add(
      client.pusherErrorEventStream.listen((event) {
        onError?.call(
          StateError('Pusher error event: ${event.data}'),
          StackTrace.current,
        );
      }),
    );

    _client = client;
    _channel = channel;
    _activeSignature = signature;

    await client.connect();
  }

  @override
  Future<void> stop() async {
    final channel = _channel;
    final client = _client;

    _activeSignature = null;
    _channel = null;
    _client = null;

    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();

    if (channel != null) {
      channel.unsubscribe();
    }
    if (client != null) {
      try {
        await client.disconnect();
      } on Object {
        // Best-effort shutdown keeps the fallback poll path alive.
      }
      try {
        client.dispose();
      } on Object {
        // A disposed client cannot be reused, so ignore duplicate shutdowns.
      }
    }
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }
}

final class _WidgetPrivateChannelAuthorizationDelegate
    implements EndpointAuthorizableChannelAuthorizationDelegate<PrivateChannelAuthorizationData> {
  const _WidgetPrivateChannelAuthorizationDelegate({
    required this.httpClient,
    required this.authorizationEndpoint,
    required this.widgetKey,
    required this.token,
  });

  final http.Client httpClient;
  final Uri authorizationEndpoint;
  final String widgetKey;
  final String token;

  @override
  EndpointAuthFailedCallback? get onAuthFailed => null;

  @override
  Future<PrivateChannelAuthorizationData> authorizationData(
    String socketId,
    String channelName,
  ) async {
    final response = await httpClient.post(
      authorizationEndpoint,
      headers: <String, String>{
        'content-type': 'application/json',
        'x-widget-token': token,
      },
      body: jsonEncode(<String, Object?>{
        'key': widgetKey,
        'socket_id': socketId,
        'channel_name': channelName,
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Widget realtime auth failed with status ${response.statusCode}.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Widget realtime auth returned invalid JSON.');
    }
    final auth = decoded['auth'];
    if (auth is! String || auth.isEmpty) {
      throw const FormatException(
        'Widget realtime auth response is missing the auth key.',
      );
    }
    return PrivateChannelAuthorizationData(authKey: auth);
  }
}
