part of '../wisperbot_runtime.dart';

/// Coordinates identity-scoped restoration and secure session persistence for
/// one runtime.
///
/// The active namespace changes before another identity can restore, ensuring
/// a token from one visitor scope is never sent for another visitor.
final class _SessionCoordinator {
  _SessionCoordinator({
    required this.config,
    required WisperBotUser? initialUser,
    required WidgetRemoteDataSource remoteDataSource,
    required WisperBotSessionStore sessionStore,
  })  : _remoteDataSource = remoteDataSource,
        _sessionStore = sessionStore,
        _activeUser = initialUser {
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

  Future<WidgetSessionResult> start({String? deviceId}) async {
    final stored = _session ?? await _readStoredSession();
    final result = await _remoteDataSource.startSession(
      widgetKey: config.widgetKey,
      user: _activeUser,
      storedSession: stored,
      preChatCompleted: stored?.preChatCompleted ?? false,
      deviceId: deviceId,
    );
    final persisted = _withActiveIdentity(result.session);
    await _writeStoredSession(persisted);
    _session = persisted;
    return result;
  }

  Future<WidgetSessionResult> submitPreChat(
    WisperBotPreChatData preChat, {
    String? deviceId,
  }) async {
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
        customFields: active?.customFields,
      ),
      storedSession: current,
      preChatCompleted: true,
      deviceId: deviceId,
    );
    final persisted = _withActiveIdentity(result.session);
    await _writeStoredSession(persisted);
    _session = persisted;
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
      identityFingerprint: current.identityFingerprint,
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
    validateWisperBotUser(user);

    final previousNamespace = _namespace;
    final nextEphemeral = createEphemeralScopeId();
    final nextNamespace = sessionNamespace(
      config: config,
      user: user,
      unsignedEphemeralScope: nextEphemeral,
    );
    _activeUser = user;
    if (nextNamespace == previousNamespace) {
      await _deleteStoredSession(nextNamespace);
      _session = null;
      return true;
    }
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
      final stored = await _sessionStore.read(_namespace);
      if (stored == null) return null;
      final expected = wisperBotUserProfileFingerprint(_activeUser);
      final saved = stored.identityFingerprint;
      final legacyIdentifiedSession = saved == null &&
          _activeUser != null &&
          !isAnonymousEquivalentUser(_activeUser);
      if (legacyIdentifiedSession || (saved != null && saved != expected)) {
        await _deleteStoredSession(_namespace);
        return null;
      }
      return stored;
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
    } on Object catch (error) {
      if (kDebugMode) {
        final code =
            error is PlatformException ? error.code : error.runtimeType;
        final status = error is PlatformException && error.details is int
            ? ' (OSStatus: ${error.details})'
            : '';
        debugPrint('[WisperBot] Secure session write failed: $code$status');
      }
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'Could not save the chat session securely.',
        retryable: false,
      );
    }
  }

  WisperBotStoredSession _withActiveIdentity(WisperBotStoredSession session) =>
      WisperBotStoredSession(
        visitorId: session.visitorId,
        token: session.token,
        savedAt: session.savedAt,
        preChatCompleted: session.preChatCompleted,
        identityFingerprint: wisperBotUserProfileFingerprint(_activeUser),
        schemaVersion: session.schemaVersion,
      );

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
      isAnonymousEquivalentUser(_activeUser) ||
      _activeUser?.signature != null ||
      unsignedStableIdentityValue(_activeUser) != null;

  bool _sameUser(WisperBotUser? left, WisperBotUser? right) =>
      left?.externalId == right?.externalId &&
      left?.name == right?.name &&
      left?.email == right?.email &&
      left?.avatarUrl == right?.avatarUrl &&
      left?.signature == right?.signature &&
      mapEquals(left?.customFields, right?.customFields);
}

/// Validates configuration at the application composition boundary.
void validateWisperBotRuntimeConfig(WisperBotConfig config) {
  validateWisperBotConfig(config);
}

/// Validates a visitor identity at the application composition boundary.
void validateWisperBotRuntimeUser(WisperBotUser? user) {
  validateWisperBotUser(user);
}

/// Returns the identity-scoped key used to prevent duplicate presentations.
String wisperBotPresentationScope(WisperBotConfig config) =>
    presentationScopeKey(config);

/// Returns the identity-scoped key used to prevent duplicate presentations.
String wisperBotUserPresentationScope(
  WisperBotConfig config,
  WisperBotUser? user,
) =>
    presentationScopeKey(config, user: user);

/// Clears default secure credentials without exposing storage to presentation.
Future<void> resetWisperBotStoredSession(
  WisperBotConfig config, {
  WisperBotUser? user,
}) async {
  validateWisperBotConfig(config);
  validateWisperBotUser(user);
  if (user != null &&
      !isAnonymousEquivalentUser(user) &&
      user.signature == null &&
      unsignedStableIdentityValue(user) == null) {
    return;
  }
  final namespace = sessionNamespace(config: config, user: user);
  final store = config.sessionStore ?? FlutterSecureWisperBotSessionStore();
  await store.delete(namespace);
}
