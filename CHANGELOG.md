# Changelog

## 0.1.0-dev.1

- Converted the repository from a Flutter application scaffold to a reusable Flutter package with a cross-platform example app.
- Added secure, identity-scoped visitor session persistence with injectable storage and HTTP transport.
- Added anonymous and verified-user session initialization, controlled token restoration, identity switching, and logout/reset behavior.
- Added typed immutable chat state, events, capabilities, and redacted errors/diagnostics.
- Added serialized lifecycle-aware polling, message ordering/deduplication, send/server-echo reconciliation, and honest unconfirmed delivery states.
- Added text, image/audio upload transport, typing throttling, and human handoff for capabilities supported by the current visitor API.
- Added full-screen, launcher, embedded, bottom-sheet/dialog, and headless integration surfaces.
- Added Material UI defaults, host/server theme resolution, loading/empty/error/reconnecting/offline states, message statuses, and accessibility semantics.
- Kept the initial built-in copy in English; localization delegates/label overrides remain a pre-stable API task rather than exposing a non-functional locale option.
- Documented current backend gates: required pre-chat bootstrap, native application policy, backward pagination, unread/read state, idempotency, realtime, and push.
- Fixed duplicate outgoing bubbles by deferring visitor poll echoes while the matching send response is still in flight, then reconciling by exact server ID.
- Moved the example widget key and API base URL into a local `.env` file and disabled the example app's debug banner.
- Aligned the default Flutter chat UI with the WisperBot web widget: branded header, compact tailed bubbles, persistent welcome bubble, muted canvas, borderless composer, circular send action, and powered-by footer.
