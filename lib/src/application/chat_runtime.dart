import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../data/session_scope.dart';
import '../data/session_store.dart';
import '../data/widget_api.dart';
import '../domain/config.dart';
import '../domain/errors.dart';
import '../domain/events.dart';
import '../domain/models.dart';

class WisperBotClient {
  WisperBotClient({
    required this.config,
    http.Client? httpClient,
    WisperBotSessionStore? sessionStore,
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _sessionStore = sessionStore ?? FlutterSecureWisperBotSessionStore(),
        _activeUser = config.user {
    validateWisperBotConfig(config);
    _baseUrl = validateAndCanonicalizeBaseUrl(config.apiBaseUrl);
    _unsignedEphemeralScope = createEphemeralScopeId();
    _namespace = sessionNamespace(
      config: config,
      user: _activeUser,
      unsignedEphemeralScope: _unsignedEphemeralScope,
    );
    _api = WidgetApiClient(baseUrl: _baseUrl, httpClient: _httpClient);
  }

  final WisperBotConfig config;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final WisperBotSessionStore _sessionStore;
  late final Uri _baseUrl;
  late final WidgetApiClient _api;
  late String _unsignedEphemeralScope;
  late String _namespace;
  WisperBotUser? _activeUser;
  WisperBotStoredSession? _session;
  bool _closed = false;

  Future<WidgetSessionResult> _startSession() async {
    _ensureOpen();
    final stored = _session ?? await _readStoredSession();
    final result = await _api.startSession(
      widgetKey: config.widgetKey,
      user: _activeUser,
      storedSession: stored,
      preChatCompleted: stored?.preChatCompleted ?? false,
    );
    await _writeStoredSession(result.session);
    _session = result.session;
    return result;
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
  ) async {
    final current = _requireSession();
    final active = _activeUser;
    final result = await _api.startSession(
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

  Future<void> _markPreChatCompleted() async {
    final current = _requireSession();
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

  Future<bool> _switchUser(WisperBotUser? user) async {
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
    if (user == null) {
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

    final nextEphemeral = createEphemeralScopeId();
    final nextNamespace = sessionNamespace(
      config: config,
      user: user,
      unsignedEphemeralScope: nextEphemeral,
    );
    _activeUser = user;
    if (nextNamespace == previousNamespace) {
      return true;
    }
    _unsignedEphemeralScope = nextEphemeral;
    _namespace = nextNamespace;
    _session = null;
    return true;
  }

  Future<void> _clearSession() async {
    await _deleteStoredSession(_namespace);
    _session = null;
  }

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

  WisperBotStoredSession _requireSession() {
    _ensureOpen();
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

  void _ensureOpen() {
    if (_closed) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'The WisperBot client is closed.',
        retryable: false,
      );
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _session = null;
    if (_ownsHttpClient) _httpClient.close();
  }
}

class WisperBotChatController with WidgetsBindingObserver {
  WisperBotChatController({required WisperBotClient client})
      : _client = client {
    _statesController = StreamController<WisperBotChatState>.broadcast(
      sync: true,
      onListen: () => _setStateLease(true),
      onCancel: () => _setStateLease(false),
    );
    _eventsController = StreamController<WisperBotChatEvent>.broadcast(
      sync: true,
      onListen: () => _setEventLease(true),
      onCancel: () => _setEventLease(false),
    );
  }

  final WisperBotClient _client;
  late final StreamController<WisperBotChatState> _statesController;
  late final StreamController<WisperBotChatEvent> _eventsController;
  WisperBotChatState _state = WisperBotChatState.initial();
  Future<void>? _initializing;
  Future<void>? _pollInFlight;
  Future<void> _sendQueue = Future<void>.value();
  final Map<int, WisperBotMessage> _deferredVisitorPollMessages =
      <int, WisperBotMessage>{};
  Timer? _pollTimer;
  Timer? _typingIdleTimer;
  DateTime? _lastTypingSentAt;
  DateTime _lastActivity = DateTime.now();
  int _pollCursor = 0;
  int _pollFailures = 0;
  Duration? _pollRetryAfter;
  bool _stateLease = false;
  bool _eventLease = false;
  bool _foreground = true;
  bool _observingLifecycle = false;
  bool _disposed = false;
  bool _recoveryAttempted = false;
  String? _activeSendLocalId;

  WisperBotChatState get state => _state;

  Stream<WisperBotChatState> get states => _statesController.stream;

  Stream<WisperBotChatEvent> get events => _eventsController.stream;

  WisperBotConfig get config => _client.config;

  Future<void> initialize() {
    _ensureNotDisposed();
    if (_state.phase == WisperBotChatPhase.ready) {
      return Future<void>.value();
    }
    final active = _initializing;
    if (active != null) return active;
    final future = _initializeInternal();
    _initializing = future;
    return future.whenComplete(() {
      if (identical(_initializing, future)) _initializing = null;
    });
  }

  Future<void> _initializeInternal() async {
    final started = DateTime.now();
    _observeLifecycle();
    _emit(
      _state.copyWith(
        phase: WisperBotChatPhase.initializing,
        connection: WisperBotConnectionState.connecting,
        error: null,
      ),
    );
    try {
      final result = await _client._startSession();
      _validatePreChatFields(result.widget);
      final preChatSatisfied = result.session.preChatCompleted ||
          _activeUserSatisfiesPreChat(result.widget);
      if (result.widget.requiresPreChat && !preChatSatisfied) {
        _emit(
          _state.copyWith(
            phase: WisperBotChatPhase.awaitingPreChat,
            messages: const <WisperBotMessage>[],
            connection: WisperBotConnectionState.connected,
            widget: result.widget,
            handoff: result.handoff,
            supportAvailability: result.supportAvailability,
            visitorTyping: false,
            agentTyping: null,
            pendingCount: 0,
            error: null,
          ),
        );
        _diagnostic(
          WisperBotDiagnosticKind.initialization,
          duration: DateTime.now().difference(started),
        );
        return;
      }
      if (result.widget.requiresPreChat && !result.session.preChatCompleted) {
        await _client._markPreChatCompleted();
      }
      await _acceptSession(result);
      _diagnostic(
        WisperBotDiagnosticKind.initialization,
        duration: DateTime.now().difference(started),
      );
    } on Object catch (error) {
      final exception = _asWisperBotException(error);
      _emit(
        _state.copyWith(
          phase: WisperBotChatPhase.failure,
          connection: WisperBotConnectionState.disconnected,
          error: exception,
        ),
      );
      _diagnostic(
        WisperBotDiagnosticKind.initialization,
        duration: DateTime.now().difference(started),
        exception: exception,
      );
      rethrow;
    }
  }

  Future<void> _acceptSession(WidgetSessionResult result) async {
    var messages = _mergeMessages(
      const <WisperBotMessage>[],
      result.messages,
      emitReceivedEvents: false,
    );
    _pollCursor = _greatestServerId(result.messages, fallback: 0);
    var latestBatchLength = result.messages.length;
    var catchUpPages = 0;
    while (latestBatchLength == 100 && catchUpPages < 50) {
      final page = await _client._poll(_pollCursor);
      messages = _mergeMessages(
        messages,
        page.messages,
        emitReceivedEvents: false,
      );
      _pollCursor = _greatestServerId(
        page.messages,
        fallback: _pollCursor,
      );
      latestBatchLength = page.messages.length;
      catchUpPages++;
    }

    _pollFailures = 0;
    _pollRetryAfter = null;
    _lastActivity = DateTime.now();
    _emit(
      _state.copyWith(
        phase: WisperBotChatPhase.ready,
        messages: messages,
        connection: WisperBotConnectionState.connected,
        widget: result.widget,
        handoff: result.handoff,
        supportAvailability: result.supportAvailability,
        visitorTyping: false,
        agentTyping: null,
        pendingCount: _pendingCount(messages),
        error: null,
      ),
    );
    _addEvent(const WisperBotSessionReady());
    _schedulePoll();
  }

  Future<void> submitPreChat(WisperBotPreChatData data) async {
    _ensureNotDisposed();
    if (_state.phase != WisperBotChatPhase.awaitingPreChat ||
        _state.widget == null) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Pre-chat information is not currently required.',
        retryable: false,
      );
    }
    final widget = _state.widget!;
    _validatePreChatSubmission(widget, data);
    _emit(_state.copyWith(connection: WisperBotConnectionState.connecting));
    try {
      final result = await _client._submitPreChat(
        WisperBotPreChatData(
          name: data.name?.trim(),
          email: data.email?.trim(),
        ),
      );
      _validatePreChatFields(result.widget);
      await _acceptSession(result);
    } on Object catch (error) {
      final exception = _asWisperBotException(error);
      _emit(
        _state.copyWith(
          phase: WisperBotChatPhase.awaitingPreChat,
          connection: WisperBotConnectionState.connected,
          error: exception,
        ),
      );
      rethrow;
    }
  }

  bool _activeUserSatisfiesPreChat(WisperBotWidgetConfig widget) {
    final user = _client._activeUser;
    if (user == null) return false;
    for (final field in widget.preChatFields) {
      switch (field) {
        case WisperBotPreChatField.name:
          if (user.name?.trim().isNotEmpty != true) return false;
        case WisperBotPreChatField.email:
          if (user.email?.trim().isNotEmpty != true) return false;
        case WisperBotPreChatField.unknown:
          return false;
      }
    }
    return true;
  }

  void _validatePreChatFields(WisperBotWidgetConfig widget) {
    if (widget.requiresPreChat &&
        widget.preChatFields.contains(WisperBotPreChatField.unknown)) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unsupported,
        message: 'This widget requires an unsupported pre-chat field.',
        retryable: false,
      );
    }
  }

  void _validatePreChatSubmission(
    WisperBotWidgetConfig widget,
    WisperBotPreChatData data,
  ) {
    final name = data.name?.trim() ?? '';
    final email = data.email?.trim() ?? '';
    if (widget.preChatFields.contains(WisperBotPreChatField.name) &&
        name.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Name is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'name': <String>['Name is required.'],
        },
      );
    }
    if (name.length > 120) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Name must be 120 characters or fewer.',
        retryable: false,
      );
    }
    if (widget.preChatFields.contains(WisperBotPreChatField.email) &&
        email.isEmpty) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Email is required.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Email is required.'],
        },
      );
    }
    if (email.length > 190 ||
        (email.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email))) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Enter a valid email address.',
        retryable: false,
        fieldErrors: <String, List<String>>{
          'email': <String>['Enter a valid email address.'],
        },
      );
    }
  }

  Future<void> refresh() {
    _ensureNotDisposed();
    final active = _pollInFlight;
    if (active != null) return active;
    if (_state.phase != WisperBotChatPhase.ready &&
        _state.phase != WisperBotChatPhase.reconnecting) {
      return initialize();
    }
    final future = _refreshInternal();
    _pollInFlight = future;
    return future.whenComplete(() {
      if (identical(_pollInFlight, future)) _pollInFlight = null;
    });
  }

  Future<void> _refreshInternal() async {
    _pollTimer?.cancel();
    try {
      final result = await _client._poll(_pollCursor);
      final messages = _mergePollMessages(
        _state.messages,
        result.messages,
        emitReceivedEvents: true,
      );
      _pollCursor = _greatestServerId(
        result.messages,
        fallback: _pollCursor,
      );
      if (result.messages.isNotEmpty) _lastActivity = DateTime.now();
      _pollFailures = 0;
      _pollRetryAfter = null;
      _recoveryAttempted = false;
      _emit(
        _state.copyWith(
          phase: WisperBotChatPhase.ready,
          messages: messages,
          connection: WisperBotConnectionState.connected,
          handoff: result.handoff,
          supportAvailability: result.supportAvailability,
          agentTyping: result.agentTyping,
          pendingCount: _pendingCount(messages),
          error: null,
        ),
      );
      _diagnostic(WisperBotDiagnosticKind.poll);
      if (result.messages.length == 100) {
        await _refreshInternal();
        return;
      }
    } on WisperBotException catch (exception) {
      if ((exception.code == WisperBotErrorCode.sessionExpired ||
              exception.code == WisperBotErrorCode.unauthorized) &&
          !_recoveryAttempted) {
        _recoveryAttempted = true;
        _emit(
          _state.copyWith(
            phase: WisperBotChatPhase.expired,
            connection: WisperBotConnectionState.disconnected,
            error: exception,
          ),
        );
        await _client._clearSession();
        await _initializeInternal();
        return;
      }
      _pollFailures++;
      _pollRetryAfter = exception.retryAfter;
      _emit(
        _state.copyWith(
          phase: !exception.retryable
              ? WisperBotChatPhase.failure
              : WisperBotChatPhase.reconnecting,
          connection: !exception.retryable
              ? WisperBotConnectionState.disconnected
              : WisperBotConnectionState.reconnecting,
          error: exception,
        ),
      );
      _diagnostic(WisperBotDiagnosticKind.poll, exception: exception);
      rethrow;
    } finally {
      _schedulePoll();
    }
  }

  Future<WisperBotMessage> sendText(String text) {
    final body = text.trim();
    if (body.isEmpty || body.length > 4000) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Messages must contain between 1 and 4,000 characters.',
        retryable: false,
      );
    }
    return _enqueueSend(() => _sendTextInternal(body));
  }

  Future<WisperBotMessage> _sendTextInternal(
    String text, {
    String? existingLocalId,
  }) async {
    _ensureReady();
    final pending = WisperBotMessage(
      localId: existingLocalId ?? _newLocalId(),
      role: WisperBotMessageRole.visitor,
      type: WisperBotMessageType.text,
      body: text,
      status: WisperBotMessageStatus.pending,
      createdAt: DateTime.now(),
      sentBy: WisperBotSenderKind.visitor,
    );
    _upsertLocal(pending);
    unawaited(setTyping(false).catchError((_) {}));
    return _performSend(pending, () => _client._sendText(text));
  }

  Future<WisperBotMessage> sendImage(
    WisperBotUpload upload, {
    String? caption,
  }) =>
      _enqueueSend(
        () => _sendUploadInternal(
          upload,
          WisperBotMessageType.image,
          caption?.trim(),
        ),
      );

  Future<WisperBotMessage> sendAudio(
    WisperBotUpload upload, {
    String? caption,
  }) =>
      _enqueueSend(
        () => _sendUploadInternal(
          upload,
          WisperBotMessageType.audio,
          caption?.trim(),
        ),
      );

  Future<WisperBotMessage> _sendUploadInternal(
    WisperBotUpload upload,
    WisperBotMessageType type,
    String? caption,
  ) async {
    _ensureReady();
    final pending = WisperBotMessage(
      localId: _newLocalId(),
      role: WisperBotMessageRole.visitor,
      type: type,
      body: caption?.isNotEmpty == true
          ? caption!
          : type == WisperBotMessageType.image
              ? 'Image attachment'
              : 'Voice message',
      status: WisperBotMessageStatus.pending,
      createdAt: DateTime.now(),
      sentBy: WisperBotSenderKind.visitor,
    );
    _upsertLocal(pending);
    return _performSend(
      pending,
      () => _client._sendUpload(upload, type, caption),
    );
  }

  Future<WisperBotMessage> _performSend(
    WisperBotMessage pending,
    Future<WidgetSendResult> Function() operation,
  ) async {
    final started = DateTime.now();
    _activeSendLocalId = pending.localId;
    try {
      final result = await operation();
      final confirmed = result.message.copyWith(
        localId: pending.localId,
        status: WisperBotMessageStatus.sent,
        clearError: true,
      );
      _replaceLocal(pending.localId, confirmed);
      _updateHandoff(result.handoff);
      _lastActivity = DateTime.now();
      _addEvent(WisperBotMessageSent(message: confirmed));
      _diagnostic(
        WisperBotDiagnosticKind.send,
        duration: DateTime.now().difference(started),
      );
      return confirmed;
    } on Object catch (error) {
      final exception = _asWisperBotException(error);
      final ambiguous = exception.code == WisperBotErrorCode.network ||
          exception.code == WisperBotErrorCode.server;
      final failed = pending.copyWith(
        status: ambiguous
            ? WisperBotMessageStatus.unconfirmed
            : WisperBotMessageStatus.failed,
        error: exception,
      );
      _replaceLocal(pending.localId, failed);
      _diagnostic(
        WisperBotDiagnosticKind.send,
        duration: DateTime.now().difference(started),
        exception: exception,
      );
      if (exception.code == WisperBotErrorCode.sessionExpired ||
          exception.code == WisperBotErrorCode.unauthorized) {
        unawaited(_recoverAfterSend());
      }
      throw exception;
    } finally {
      if (_activeSendLocalId == pending.localId) {
        _activeSendLocalId = null;
        _flushDeferredVisitorPollMessages();
      }
    }
  }

  Future<void> _recoverAfterSend() async {
    if (_recoveryAttempted || _disposed) return;
    _recoveryAttempted = true;
    _emit(
      _state.copyWith(
        phase: WisperBotChatPhase.expired,
        connection: WisperBotConnectionState.disconnected,
      ),
    );
    try {
      await _client._clearSession();
      await _initializeInternal();
    } on Object {
      // The state emitted by initialization remains authoritative.
    }
  }

  Future<WisperBotMessage> retryMessage(String localId) {
    final message = _findLocal(localId);
    if (message.status != WisperBotMessageStatus.failed ||
        message.error?.retryable != true ||
        message.type != WisperBotMessageType.text) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'This message cannot be retried safely.',
        retryable: false,
      );
    }
    return _enqueueSend(
      () => _sendTextInternal(message.body, existingLocalId: localId),
    );
  }

  Future<void> removeMessage(String localId) async {
    final message = _findLocal(localId);
    if (message.status != WisperBotMessageStatus.failed &&
        message.status != WisperBotMessageStatus.unconfirmed) {
      throw const WisperBotException(
        code: WisperBotErrorCode.validation,
        message: 'Only failed or unconfirmed messages can be removed.',
        retryable: false,
      );
    }
    final messages =
        _state.messages.where((item) => item.localId != localId).toList();
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  Future<void> setTyping(bool isTyping) async {
    if (!_client.config.enableTyping ||
        _state.phase != WisperBotChatPhase.ready) {
      return;
    }
    _typingIdleTimer?.cancel();
    if (isTyping) {
      _emit(_state.copyWith(visitorTyping: true));
      _typingIdleTimer = Timer(const Duration(seconds: 4), () {
        unawaited(setTyping(false).catchError((_) {}));
      });
      final now = DateTime.now();
      if (_lastTypingSentAt != null &&
          now.difference(_lastTypingSentAt!) < const Duration(seconds: 2)) {
        return;
      }
      _lastTypingSentAt = now;
    } else {
      if (!_state.visitorTyping) return;
      _emit(_state.copyWith(visitorTyping: false));
    }
    try {
      await _client._setTyping(isTyping);
    } on Object {
      if (!isTyping) _emit(_state.copyWith(visitorTyping: false));
    }
  }

  Future<void> requestHumanAgent() async {
    _ensureReady();
    if (_state.handoff.status != WisperBotHandoffStatus.eligible) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unsupported,
        message: 'Human handoff is not available.',
        retryable: false,
      );
    }
    _updateHandoff(
      const WisperBotHandoffState(
        status: WisperBotHandoffStatus.requesting,
      ),
    );
    try {
      _updateHandoff(await _client._requestHandoff());
    } on Object catch (error) {
      final exception = _asWisperBotException(error);
      _updateHandoff(
        WisperBotHandoffState(
          status: WisperBotHandoffStatus.failed,
          error: exception,
        ),
      );
      throw exception;
    }
  }

  Future<void> updateUser(WisperBotUser? user) async {
    _ensureNotDisposed();
    _cancelPoll();
    final changed = await _client._switchUser(user);
    if (!changed) return;
    _deferredVisitorPollMessages.clear();
    _pollCursor = 0;
    _recoveryAttempted = false;
    _emit(
      WisperBotChatState.initial().copyWith(
        phase: WisperBotChatPhase.initializing,
        connection: WisperBotConnectionState.connecting,
      ),
    );
    await initialize();
  }

  Future<void> resetSession() async {
    _ensureNotDisposed();
    _cancelPoll();
    await _client._clearSession();
    _deferredVisitorPollMessages.clear();
    _pollCursor = 0;
    _recoveryAttempted = false;
    _addEvent(
      const WisperBotChatClosed(reason: WisperBotChatCloseReason.sessionReset),
    );
    _emit(WisperBotChatState.initial());
    if (_hasLease) await initialize();
  }

  @internal
  void handlePresentationOpened() {
    _addEvent(const WisperBotChatOpened());
  }

  @internal
  void handlePresentationClosed(WisperBotChatCloseReason reason) {
    _addEvent(WisperBotChatClosed(reason: reason));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _diagnostic(WisperBotDiagnosticKind.lifecycle);
    if (_foreground) {
      if (_hasLease && _state.phase == WisperBotChatPhase.ready) {
        unawaited(refresh().catchError((_) {}));
      }
    } else {
      _cancelPoll();
      _typingIdleTimer?.cancel();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _cancelPoll();
    _typingIdleTimer?.cancel();
    _deferredVisitorPollMessages.clear();
    if (_observingLifecycle) {
      WidgetsBinding.instance.removeObserver(this);
      _observingLifecycle = false;
    }
    _state = _state.copyWith(
      phase: WisperBotChatPhase.disposed,
      connection: WisperBotConnectionState.disconnected,
      visitorTyping: false,
      agentTyping: null,
    );
    if (!_statesController.isClosed) _statesController.add(_state);
    await _statesController.close();
    await _eventsController.close();
  }

  void _setStateLease(bool active) {
    _stateLease = active;
    _leaseChanged();
  }

  void _setEventLease(bool active) {
    _eventLease = active;
    _leaseChanged();
  }

  bool get _hasLease => _stateLease || _eventLease;

  void _leaseChanged() {
    if (_disposed) return;
    if (_hasLease) {
      _schedulePoll();
    } else {
      _cancelPoll();
    }
  }

  void _schedulePoll() {
    _pollTimer?.cancel();
    if (_disposed ||
        !_foreground ||
        !_hasLease ||
        (_state.phase != WisperBotChatPhase.ready &&
            _state.phase != WisperBotChatPhase.reconnecting)) {
      return;
    }
    final duration = _effectivePollInterval();
    _pollTimer = Timer(duration, () {
      unawaited(refresh().catchError((_) {}));
    });
  }

  Duration _effectivePollInterval() {
    const minimum = Duration(seconds: 3);
    if (_pollFailures > 0) {
      final retryAfter = _pollRetryAfter;
      if (retryAfter != null) {
        return retryAfter < minimum ? minimum : retryAfter;
      }
      final seconds = min(3 * pow(2, min(_pollFailures, 4)).toInt(), 30);
      final jitter = 0.85 + Random.secure().nextDouble() * 0.3;
      final backoff = Duration(milliseconds: (seconds * 1000 * jitter).round());
      final configuredMax = _client.config.polling.failureMaxInterval;
      final bounded = backoff > configuredMax ? configuredMax : backoff;
      return bounded < minimum ? minimum : bounded;
    }
    final configured =
        DateTime.now().difference(_lastActivity) > const Duration(seconds: 30)
            ? _client.config.polling.idleInterval
            : _client.config.polling.visibleInterval;
    return configured < minimum ? minimum : configured;
  }

  void _cancelPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void _observeLifecycle() {
    if (_observingLifecycle) return;
    WidgetsBinding.instance.addObserver(this);
    _observingLifecycle = true;
  }

  Future<T> _enqueueSend<T>(Future<T> Function() operation) {
    _ensureNotDisposed();
    final completer = Completer<T>();
    _sendQueue = _sendQueue.then((_) async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  List<WisperBotMessage> _mergeMessages(
    List<WisperBotMessage> existing,
    List<WisperBotMessage> incoming, {
    required bool emitReceivedEvents,
  }) {
    final messages = <WisperBotMessage>[...existing];
    final indexes = <int, int>{};
    for (var index = 0; index < messages.length; index++) {
      final id = messages[index].serverId;
      if (id != null) indexes[id] = index;
    }
    for (final message in incoming) {
      final id = message.serverId;
      if (id == null) continue;
      final existingIndex = indexes[id];
      if (existingIndex == null) {
        indexes[id] = messages.length;
        messages.add(message);
        if (emitReceivedEvents && message.role == WisperBotMessageRole.agent) {
          _addEvent(WisperBotMessageReceived(message: message));
        }
      } else {
        messages[existingIndex] = message.copyWith(
          localId: messages[existingIndex].localId,
        );
      }
    }
    messages.sort(_compareMessages);
    return messages;
  }

  List<WisperBotMessage> _mergePollMessages(
    List<WisperBotMessage> existing,
    List<WisperBotMessage> incoming, {
    required bool emitReceivedEvents,
  }) {
    if (_activeSendLocalId == null) {
      return _mergeMessages(
        existing,
        incoming,
        emitReceivedEvents: emitReceivedEvents,
      );
    }

    final knownServerIds =
        existing.map((message) => message.serverId).whereType<int>().toSet();
    final immediate = <WisperBotMessage>[];
    for (final message in incoming) {
      final serverId = message.serverId;
      if (message.role == WisperBotMessageRole.visitor &&
          serverId != null &&
          !knownServerIds.contains(serverId)) {
        _deferredVisitorPollMessages[serverId] = message;
      } else {
        immediate.add(message);
      }
    }
    return _mergeMessages(
      existing,
      immediate,
      emitReceivedEvents: emitReceivedEvents,
    );
  }

  void _flushDeferredVisitorPollMessages() {
    if (_deferredVisitorPollMessages.isEmpty) return;
    final deferred = _deferredVisitorPollMessages.values.toList();
    _deferredVisitorPollMessages.clear();
    final messages = _mergeMessages(
      _state.messages,
      deferred,
      emitReceivedEvents: false,
    );
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  int _greatestServerId(
    List<WisperBotMessage> messages, {
    required int fallback,
  }) =>
      messages.fold<int>(
        fallback,
        (greatest, message) => message.serverId == null
            ? greatest
            : max(greatest, message.serverId!),
      );

  int _compareMessages(WisperBotMessage a, WisperBotMessage b) {
    final aId = a.serverId;
    final bId = b.serverId;
    if (aId != null && bId != null) return aId.compareTo(bId);
    if (aId != null) return -1;
    if (bId != null) return 1;
    final time = a.createdAt.compareTo(b.createdAt);
    return time != 0 ? time : a.localId.compareTo(b.localId);
  }

  void _upsertLocal(WisperBotMessage message) {
    final messages = <WisperBotMessage>[..._state.messages];
    final index =
        messages.indexWhere((item) => item.localId == message.localId);
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }
    messages.sort(_compareMessages);
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  void _replaceLocal(String localId, WisperBotMessage replacement) {
    final messages = <WisperBotMessage>[];
    final replacementServerId = replacement.serverId;
    var replaced = false;
    for (final message in _state.messages) {
      if (message.localId == localId) {
        if (!replaced) {
          messages.add(replacement);
          replaced = true;
        }
        continue;
      }
      if (replacementServerId != null &&
          message.serverId == replacementServerId) {
        continue;
      }
      messages.add(message);
    }
    if (!replaced) messages.add(replacement);
    messages.sort(_compareMessages);
    _emit(
      _state.copyWith(
        messages: messages,
        pendingCount: _pendingCount(messages),
      ),
    );
  }

  WisperBotMessage _findLocal(String localId) {
    for (final message in _state.messages) {
      if (message.localId == localId) return message;
    }
    throw const WisperBotException(
      code: WisperBotErrorCode.validation,
      message: 'The local message no longer exists.',
      retryable: false,
    );
  }

  int _pendingCount(List<WisperBotMessage> messages) => messages
      .where((message) => message.status == WisperBotMessageStatus.pending)
      .length;

  void _updateHandoff(WisperBotHandoffState handoff) {
    if (_state.handoff.status == handoff.status &&
        _state.handoff.error == handoff.error) {
      return;
    }
    _emit(_state.copyWith(handoff: handoff));
    _addEvent(WisperBotHandoffChanged(handoff: handoff));
  }

  void _emit(WisperBotChatState next) {
    if (_disposed) return;
    final connectionChanged = next.connection != _state.connection;
    _state = next;
    if (!_statesController.isClosed) _statesController.add(next);
    if (connectionChanged) {
      _addEvent(WisperBotConnectionChanged(connection: next.connection));
      _diagnostic(WisperBotDiagnosticKind.connection);
    }
  }

  void _addEvent(WisperBotChatEvent event) {
    if (!_disposed && !_eventsController.isClosed) {
      _eventsController.add(event);
    }
  }

  void _diagnostic(
    WisperBotDiagnosticKind kind, {
    Duration? duration,
    WisperBotException? exception,
  }) {
    final callback = _client.config.diagnostics;
    if (callback == null) return;
    try {
      callback(
        WisperBotDiagnosticEvent(
          kind: kind,
          occurredAt: DateTime.now().toUtc(),
          duration: duration,
          httpStatus: exception?.httpStatus,
          errorCode: exception?.code,
        ),
      );
    } on Object {
      // Diagnostics must never alter chat behavior.
    }
  }

  void _ensureReady() {
    _ensureNotDisposed();
    if (_state.phase != WisperBotChatPhase.ready &&
        _state.phase != WisperBotChatPhase.reconnecting) {
      throw const WisperBotException(
        code: WisperBotErrorCode.unauthorized,
        message: 'Chat is not ready to send a message.',
        retryable: true,
      );
    }
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw const WisperBotException(
        code: WisperBotErrorCode.configuration,
        message: 'The chat controller is disposed.',
        retryable: false,
      );
    }
  }

  String _newLocalId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
}

WisperBotException _asWisperBotException(Object error) =>
    error is WisperBotException
        ? error
        : const WisperBotException(
            code: WisperBotErrorCode.unknown,
            message: 'The chat operation could not be completed.',
            retryable: false,
          );
