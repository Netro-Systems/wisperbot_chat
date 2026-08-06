# WisperBot Flutter SDK Project Goal

## Vision

Make WisperBot visitor chat easy to add to Flutter with a widget key, while
matching the checked-in Laravel `/widget/v1` API exactly. The SDK owns secure
session restoration, API communication, foreground polling, application state,
and an optional prebuilt UI. It is not an agent inbox or management client.

## Integration modes

All integrations use the same controller and transport:

1. `WisperBotChatScreen`
2. `WisperBotChatLauncher`
3. `WisperBotChatView`
4. `WisperBotChat.open(...)`
5. Headless `WisperBotChatController`

Anonymous chat requires only a public widget key. A host may additionally pass
profile data or a server-generated identity signature. Widget identity secrets
and management credentials must never enter the application.

## Current product scope

- Anonymous and optional verified-user sessions
- Secure, identity-scoped visitor-token restoration
- Required name/email pre-chat using the token-bound session route
- Widget configuration and branding
- Text, image, and audio visitor messages
- Polling for AI, automation, broadcast, and human replies
- Visitor and agent typing state
- Human handoff after backend-reported eligibility
- Network state separated from support working-hours availability
- Full-screen, launcher, embedded, modal, and headless integrations
- Typed errors and conservative send-delivery semantics
- Accessible, localizable, light/dark default UI

The current backend has no visitor realtime channel, unread/read API, push or
device registration, server capability negotiation, backward pagination,
client message idempotency, or identity-verification outcome. Those concepts
are not exposed by this SDK.

## Backend contract

At backend commit `3dfe430`, the visitor operations are:

- `POST /widget/v1/session`
- `POST /widget/v1/messages` for JSON text or multipart image/audio
- `GET /widget/v1/messages` for forward polling
- `POST /widget/v1/typing`
- `POST /widget/v1/handoff`

The backend repository at `D:\Backend\wisperbot` is read-only reference
material. `docs/API.md` records the exact request and response contract.

The browser-oriented domain policy is a known limitation for native clients:
native requests do not have trustworthy `Origin` or `Referer` values. The SDK
never spoofs those headers. A widget with a non-empty browser allowlist may
therefore reject a native request until the backend supplies a native policy.

## Reliability and privacy invariants

- The encrypted visitor token, never a caller-provided conversation ID,
  authorizes history.
- Stored credentials are scoped by canonical API URL, widget key, and identity.
- Switching identity never sends the previous identity's token.
- A same-scope profile update re-posts the token-bound session.
- Pre-chat stores only a completion flag, not submitted name/email.
- Messages are ordered and deduplicated by server ID.
- Only session and poll batches advance the receive cursor.
- Ambiguous sends remain unconfirmed and are not automatically retried.
- Polls never overlap and stop when unused or backgrounded.
- Tokens, signatures, PII, message bodies, and attachment URLs are not logged.

## Success criteria

- A developer can open anonymous chat with a widget key and a few lines of Dart.
- Every SDK request is accepted by the current backend without invented fields
  or headers.
- Returning visitors cannot cross identity scopes on a shared device.
- Required pre-chat is completed before the composer becomes available.
- AI and human replies reconcile through foreground polling.
- No application-shipped secret is required.

## Non-goals

- Agent inbox, workspace administration, or chatbot training
- On-device signature generation
- Background delivery without a backend push contract
- Read receipts or unread counts
- Visitor realtime subscriptions
- Fabricating feature support not present in the current backend
