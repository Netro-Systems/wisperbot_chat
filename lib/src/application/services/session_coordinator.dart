part of '../wisperbot_runtime.dart';

/// Coordinates identity-scoped restoration and secure session persistence.
///
/// The active namespace changes before another identity can restore, ensuring
/// a token from one visitor scope is never sent for another visitor.
final class _SessionCoordinator {
  _SessionCoordinator({
    required this.config,
    required WidgetRemoteDataSource remoteDataSource,
    required WisperBotSessionStore sessionStore,
  })  : _remoteDataSource = remoteDataSource,
        _sessionStore = sessionStore,
        _activeUser = config.user {
    _unsignedEphemeralScope = createEphemeralScopeId();
    _namespace = sessionNamespace(
      config: config,
      user: _activeUser,
      unsignedEphemeralScope: _unsignedEphemeralScope,
    );
  }

  final WisperBotConfig config;
  final WidgetRemoteDataSource _remoteDataSource;
  final WisperBotSessionStore _sessionStore;
  late String _unsignedEphemeralScope;
  late String _namespace;
  WisperBotUser? _activeUser;
  WisperBotStoredSession? _session;

  WisperBotUser? get activeUser => _activeUser;

  Future<WidgetSessionResult> start() async {
    final stored = _session ?? await _readStoredSession();
    final result = await _remoteDataSource.startSession(
      widgetKey: config.widgetKey,
      user: _activeUser,
      storedSession: stored,
      preChatCompleted: stored?.preChatCompleted ?? false,
    );
    await _writeStoredSession(result.session);
    _session = result.session;
    return result;
  }

  Future<WidgetSessionResult> submitPreChat(
      WisperBotPreChatData preChat) async {
    final current = requireSession();
    final active = _activeUser;
    final result = await _remoteDataSource.startSession(
      widgetKey: config.widgetKey,
      user: WisperBotUser(
        externalId: active?.externalId,
        name: preChat.name ?? active?.name,
        email: preChat.email ?? active?.email,
        avatarUrl: active?.avatarUrl,
        signature: active?.signature,
      ),
      storedSession: current,
      preChatCompleted: true,
    );
    await _writeStoredSession(result.session);
    _session = result.session;
    return result;
  }

  Future<void> markPreChatCompleted() async {
    final current = requireSession();
    if (current.preChatCompleted) return;
    final completed = WisperBotStoredSession(
      visitorId: current.visitorId,
      token: current.token,
      savedAt: current.savedAt,
      preChatCompleted: true,
      schemaVersion: current.schemaVersion,
    );
    await _writeStoredSession(completed);
    _session = completed;
  }

  Future<bool> switchUser(WisperBotUser? user) async {
    // Passing null is the host application's logout signal, even when the
    // current chat scope is already anonymous. Always discard that scope so a
    // later initialize cannot restore pre-logout visitor credentials.
    if (user == null) {
      final previousNamespace = _namespace;
      await _deleteStoredSession(previousNamespace);
      _activeUser = null;
      _unsignedEphemeralScope = createEphemeralScopeId();
      _namespace = sessionNamespace(config: config, user: null);
      if (_namespace != previousNamespace) {
        await _deleteStoredSession(_namespace);
      }
      _session = null;
      return true;
    }
    if (_sameUser(_activeUser, user)) return false;
    final candidate = WisperBotConfig(
      widgetKey: config.widgetKey,
      apiBaseUrl: config.apiBaseUrl,
      user: user,
      theme: config.theme,
      useApiColors: config.useApiColors,
      presentation: config.presentation,
      enableTyping: config.enableTyping,
      mediaAdapter: config.mediaAdapter,
      polling: config.polling,
      diagnostics: config.diagnostics,
    );
    validateWisperBotConfig(candidate);

    final previousNamespace = _namespace;
    final nextEphemeral = createEphemeralScopeId();
    final nextNamespace = sessionNamespace(
      config: config,
      user: user,
      unsignedEphemeralScope: nextEphemeral,
    );
    _activeUser = user;
    if (nextNamespace == previousNamespace) return true;
    _unsignedEphemeralScope = nextEphemeral;
    _namespace = nextNamespace;
    _session = null;
    return true;
  }

  Future<void> clear() async {
    await _deleteStoredSession(_namespace);
    _session = null;
  }

  WisperBotStoredSession requireSession() {
    final session = _session;
    if (session == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unauthorized,
        message: 'The chat session is not ready.',
        retryable: true,
      );
    }
    return session;
  }

  void disposeMemory() => _session = null;

  Future<WisperBotStoredSession?> _readStoredSession() async {
    if (!_shouldPersistActiveSession) return null;
    try {
      return await _sessionStore.read(_namespace);
    } on WisperBotException {
      rethrow;
    } on Object {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'Secure session storage is unavailable.',
        retryable: false,
      );
    }
  }

  Future<void> _writeStoredSession(WisperBotStoredSession session) async {
    if (!_shouldPersistActiveSession) return;
    try {
      await _sessionStore.write(_namespace, session);
    } on WisperBotException {
      rethrow;
    } on Object {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'Could not save the chat session securely.',
        retryable: false,
      );
    }
  }

  Future<void> _deleteStoredSession(String namespace) async {
    try {
      await _sessionStore.delete(namespace);
    } on WisperBotException {
      rethrow;
    } on Object {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'Could not clear the secure chat session.',
        retryable: false,
      );
    }
  }

  bool get _shouldPersistActiveSession =>
      _activeUser == null || _activeUser?.signature != null;

  bool _sameUser(WisperBotUser? left, WisperBotUser? right) =>
      left?.externalId == right?.externalId &&
      left?.name == right?.name &&
      left?.email == right?.email &&
      left?.avatarUrl == right?.avatarUrl &&
      left?.signature == right?.signature;
}

/// Validates configuration at the application composition boundary.
void validateWisperBotRuntimeConfig(WisperBotConfig config) {
  validateWisperBotConfig(config);
}

/// Returns the identity-scoped key used to prevent duplicate presentations.
String wisperBotPresentationScope(WisperBotConfig config) =>
    presentationScopeKey(config);

/// Clears default secure credentials without exposing storage to presentation.
Future<void> resetWisperBotStoredSession(WisperBotConfig config) async {
  validateWisperBotConfig(config);
  final user = config.user;
  if (user != null && user.signature == null) return;
  final namespace = sessionNamespace(config: config, user: user);
  await FlutterSecureWisperBotSessionStore().delete(namespace);
}
