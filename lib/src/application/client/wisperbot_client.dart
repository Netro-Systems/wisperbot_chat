part of '../wisperbot_runtime.dart';

/// Owns HTTP and secure-session resources for one widget configuration.
///
/// Create a controller with [WisperBotChatController] and call [close] after
/// every controller using this client has been disposed.
class WisperBotClient {
  /// Creates a client with injectable transport and credential storage.
  ///
  /// The client owns a default HTTP client and secure store. Injected
  /// dependencies remain caller-owned. Throws [WisperBotException] when the
  /// configuration is invalid.
  WisperBotClient({
    required this.config,
    http.Client? httpClient,
    WisperBotSessionStore? sessionStore,
    WidgetRealtimeConnector? realtimeConnector,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    validateWisperBotConfig(config);
    final baseUrl = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
    _remoteDataSource = _createWidgetRemoteDataSource(
      baseUrl: baseUrl,
      httpClient: _httpClient,
    );
    _sessions = _SessionCoordinator(
      config: config,
      remoteDataSource: _remoteDataSource,
      sessionStore: sessionStore ?? config.sessionStore ?? FlutterSecureWisperBotSessionStore(),
    );
    _realtimeConnector =
        realtimeConnector ?? PusherWidgetRealtimeConnector(httpClient: _httpClient);
  }

  /// Immutable configuration used for every operation.
  final WisperBotConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  late final WidgetRemoteDataSource _remoteDataSource;
  late final _SessionCoordinator _sessions;
  late final WidgetRealtimeConnector _realtimeConnector;
  bool _closed = false;

  WisperBotUser? get _activeUser => _sessions.activeUser;

  Future<WidgetSessionResult> _startSession({String? deviceId}) {
    _ensureOpen();
    return _sessions.start(deviceId: deviceId);
  }

  Future<WidgetPollResult> _poll(int after) {
    final session = _requireSession();
    return _remoteDataSource.poll(
      widgetKey: config.widgetKey,
      token: session.token,
      after: after,
    );
  }

  Future<WidgetSendResult> _sendText(String text) {
    final session = _requireSession();
    return _remoteDataSource.sendText(
      widgetKey: config.widgetKey,
      token: session.token,
      text: text,
    );
  }

  Future<WidgetSendResult> _sendUpload(
    WisperBotUpload upload,
    WisperBotMessageType type,
    String? caption,
  ) {
    final session = _requireSession();
    return _remoteDataSource.sendUpload(
      widgetKey: config.widgetKey,
      token: session.token,
      upload: upload,
      type: type,
      caption: caption,
    );
  }

  Future<Uint8List> _loadAttachmentBytes(WisperBotAttachment attachment) {
    final session = _requireSession();
    return _remoteDataSource.loadAttachmentBytes(
      token: session.token,
      attachment: attachment,
    );
  }

  Future<void> _setTyping(bool isTyping) {
    final session = _requireSession();
    return _remoteDataSource.setTyping(
      widgetKey: config.widgetKey,
      token: session.token,
      isTyping: isTyping,
    );
  }

  Future<WisperBotHandoffState> _requestHandoff() {
    final session = _requireSession();
    return _remoteDataSource.requestHandoff(
      widgetKey: config.widgetKey,
      token: session.token,
    );
  }

  Future<void> _markRead() {
    final session = _requireSession();
    return _remoteDataSource.markRead(
      widgetKey: config.widgetKey,
      token: session.token,
    );
  }

  Future<WidgetSessionResult> _submitPreChat(
    WisperBotPreChatData preChat, {
    String? deviceId,
  }) =>
      _sessions.submitPreChat(preChat, deviceId: deviceId);

  Future<void> _markPreChatCompleted() => _sessions.markPreChatCompleted();

  Future<bool> _switchUser(WisperBotUser? user) => _sessions.switchUser(user);

  Future<void> _clearSession() => _sessions.clear();

  Future<void> _startRealtime({
    required WisperBotRealtimeConfig realtime,
    required int conversationId,
    void Function()? onConnected,
    WidgetRealtimePayloadCallback? onMessageCreated,
    WidgetRealtimePayloadCallback? onTypingChanged,
    WidgetRealtimePayloadCallback? onHandoffUpdated,
    WidgetRealtimeErrorCallback? onError,
  }) {
    final session = _requireSession();
    return _realtimeConnector.start(
      config: realtime,
      widgetKey: config.widgetKey,
      token: session.token,
      conversationId: conversationId,
      onConnected: onConnected,
      onMessageCreated: onMessageCreated,
      onTypingChanged: onTypingChanged,
      onHandoffUpdated: onHandoffUpdated,
      onError: onError,
    );
  }

  Future<void> _stopRealtime() => _realtimeConnector.stop();

  WisperBotStoredSession _requireSession() {
    _ensureOpen();
    return _sessions.requireSession();
  }

  void _ensureOpen() {
    if (_closed) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'The WisperBot client is closed.',
        retryable: false,
      );
    }
  }

  /// Releases resources owned by this client.
  ///
  /// An injected HTTP client remains owned by the caller and is not closed.
  /// Calling this method repeatedly is safe.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _realtimeConnector.stop();
    _sessions.disposeMemory();
    if (_ownsHttpClient) _httpClient.close();
  }
}
