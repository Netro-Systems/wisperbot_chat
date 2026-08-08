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
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null {
    validateWisperBotConfig(config);
    final baseUrl = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
    _api = _createWidgetApiClient(baseUrl: baseUrl, httpClient: _httpClient);
    _sessions = _SessionCoordinator(
      config: config,
      api: _api,
      sessionStore: sessionStore ?? FlutterSecureWisperBotSessionStore(),
    );
  }

  /// Immutable configuration used for every operation.
  final WisperBotConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  late final WidgetApiClient _api;
  late final _SessionCoordinator _sessions;
  bool _closed = false;

  WisperBotUser? get _activeUser => _sessions.activeUser;

  Future<WidgetSessionResult> _startSession() {
    _ensureOpen();
    return _sessions.start();
  }

  Future<WidgetPollResult> _poll(int after) {
    final session = _requireSession();
    return _api.poll(
      widgetKey: config.widgetKey,
      token: session.token,
      after: after,
    );
  }

  Future<WidgetSendResult> _sendText(String text) {
    final session = _requireSession();
    return _api.sendText(
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
    return _api.sendUpload(
      widgetKey: config.widgetKey,
      token: session.token,
      upload: upload,
      type: type,
      caption: caption,
    );
  }

  Future<void> _setTyping(bool isTyping) {
    final session = _requireSession();
    return _api.setTyping(
      widgetKey: config.widgetKey,
      token: session.token,
      isTyping: isTyping,
    );
  }

  Future<WisperBotHandoffState> _requestHandoff() {
    final session = _requireSession();
    return _api.requestHandoff(
      widgetKey: config.widgetKey,
      token: session.token,
    );
  }

  Future<WidgetSessionResult> _submitPreChat(
    WisperBotPreChatData preChat,
  ) =>
      _sessions.submitPreChat(preChat);

  Future<void> _markPreChatCompleted() => _sessions.markPreChatCompleted();

  Future<bool> _switchUser(WisperBotUser? user) => _sessions.switchUser(user);

  Future<void> _clearSession() => _sessions.clear();

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
    _sessions.disposeMemory();
    if (_ownsHttpClient) _httpClient.close();
  }
}
