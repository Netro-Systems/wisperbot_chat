# WisperBot Flutter SDK Architecture

## Boundaries

```text
Flutter UI -> controller/application -> domain <- HTTP/storage
```

The package uses shared Dart HTTP and session logic and optional Flutter UI.
UI never calls HTTP directly, JSON maps do not leave the data layer, and domain
models do not depend on UI classes. Network, secure storage, lifecycle, and
media acquisition remain injectable.

The widget key selects the server widget and workspace. The encrypted visitor
token authorizes one visitor conversation. The SDK never uses a conversation
ID, chatbot ID, or agent ID as authority.

## Source layout

```text
lib/src/
|- configuration/  # Public host options and presentation configuration
|- domain/         # Immutable models, typed failures, events, contracts
|- application/    # Client/controller orchestration and focused services
|- data/           # HTTP mapping and secure-storage implementations
`- presentation/   # Optional screens, views, launcher, theme, and widgets
```

Configuration is separate from the domain because its public theme options use
Flutter UI types. Data implements domain-owned contracts. The internal
`application/wisperbot_runtime.dart` Dart library is the composition point: it
wires focused data adapters to the client/controller without exporting those
adapters. Presentation observes controller state and never imports data
directly.
Only `lib/wisperbot_chat.dart` defines the supported public surface.

The public client and controller share a private Dart library through focused
part files so their collaboration does not enlarge the public API. Request
encoding, response decoding, HTTP error mapping, session coordination,
validation, reconciliation, polling scheduling, state transitions, and UI
components remain in separate, independently testable files.

The data-layer request flow uses familiar, explicit responsibilities:

```text
ApiEndpoints -> NetworkCaller -> WidgetRemoteDataSource -> application
```

`ApiEndpoints` lists the complete `/widget/v1` surface. `NetworkCaller` is the
only component that invokes `http.Client`; it resolves URLs, applies the allowed
headers and timeout, executes JSON/multipart requests, and maps transport/HTTP
failures. `HttpWidgetRemoteDataSource` selects an operation and delegates its
wire encoding and decoding to focused mappers. The application sees typed
results rather than HTTP responses or JSON maps.

## Public surface

The intentional public API includes configuration/user models, secure session
storage, client/controller/state, messages and uploads, typed events/errors,
theme/localization, and the five presentation styles. It includes
`WisperBotPreChatData` and `submitPreChat(...)`.

There are no public visitor-realtime, capability-negotiation, unread-count,
read-receipt, or identity-outcome types because the current backend exposes no
such contracts.

## Identity and storage

The default store persists a visitor ID and token atomically in secure storage.
Its namespace derives from canonical API base URL, widget key, identity scope,
and schema version. Message bodies remain in memory.

Signed identities use a scope derived from the signed value and signature.
Unsigned profile data cannot select an authenticated history. When a user
changes:

1. Stop polling and clear visible conversation state.
2. Resolve the new identity scope.
3. Never send the outgoing scope's token into a different scope.
4. Restore or create the selected scope's session.

When profile data changes inside the same signed scope, repeat the session
request with the existing token so the backend can refresh the contact.

## State machine

```text
idle -> initializing -> awaitingPreChat -> initializing -> ready
                  \-> failure
ready -> reconnecting -> ready
ready -> expired -> initializing
ready -> disposed
```

Connection status and support availability are separate. Expected phases are
state, not exceptions.

## Initialization and pre-chat

1. Load the identity-scoped stored visitor ID/token.
2. `POST /widget/v1/session` with the widget key, optional identity fields, and
   stored token header.
3. Strictly parse credentials, configuration, history, availability, and
   handoff state.
4. If `require_prechat` lists missing `name` or `email`, enter
   `awaitingPreChat` and keep the composer hidden.
5. On submission, repeat the same session request with its visitor ID/token and
   submitted fields.
6. Replace credentials/config/history with the refreshed response and store
   only `preChatCompleted: true` alongside the secure session.
7. Enter `ready` and start foreground polling when a listener holds a sync
   lease.

Unknown required pre-chat fields are rejected as unsupported. Existing user
data or a stored completion flag skips the prompt.

## Messaging and synchronization

Text sends JSON containing only `key` and `message`. Image/audio sends use
multipart `key`, `type`, optional `message`, and `attachment`. Laravel owns
authoritative attachment validation.

Every successful session/poll batch is ordered and deduplicated by server ID.
The receive cursor advances only from those batches, never from a send response,
so a lower-ID unseen reply cannot be skipped. A full 100-message poll batch is
followed immediately by another page.

Polling is the only visitor delivery mechanism. It runs only in foreground
while needed, never overlaps, and reconciles immediately after resume. Agent
typing expires locally if later poll data does not sustain it.

A send response reconciles its local pending entry by request ownership, not by
body/time similarity. A definitive client rejection becomes failed. A timeout,
transport loss, or server error after transmission remains unconfirmed and is
not automatically retried because the backend has no idempotency key.

## Typing and handoff

Typing posts only when enabled by local configuration and the controller is
ready. Handoff is offered and posted only after the returned handoff state says
it is eligible; the current backend becomes eligible after two visitor
messages when an active AI chatbot is configured.

## HTTP and error policy

All requests send `Accept: application/json`. JSON operations set JSON content
type. Polling and multipart do not. Authenticated operations send only the real
`X-Widget-Token` credential header. The SDK sends no SDK-version, raw-upload,
`Origin`, or `Referer` headers.

Error mapping is operation-aware: session `404` is configuration failure;
authenticated `401` and conversation `404` permit one controlled restoration;
media `422` is attachment rejection; other `422` is validation; and `429`
preserves `Retry-After`.

The package intentionally keeps `http`, constructor injection, and typed
`WisperBotException` failures. It does not add Dio, a service locator, generic
result wrappers, use cases, or repository implementations that would only
forward the same visitor operations.

## Platform policy

The current Laravel domain check is browser-oriented. Web supplies its actual
origin. Native clients cannot truthfully provide browser-origin headers, so the
SDK does not fabricate them. Native use with a non-empty browser allowlist may
be rejected until a backend-native policy exists.

## Diagnostics

Diagnostics are redacted lifecycle/request outcomes only. They never contain
tokens, signatures, names, emails, external IDs, message bodies, attachment
URLs, or unverified claims about server features.
