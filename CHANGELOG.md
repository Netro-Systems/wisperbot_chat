# Changelog

## 0.1.0

### Added

- Reusable Flutter package structure with a cross-platform example app.
- Anonymous and verified-user chat sessions with secure, identity-scoped storage.
- Public widget API client with injectable HTTP transport and session storage.
- Typed chat state, events, errors, and redacted diagnostics.
- Lifecycle-aware foreground polling with message ordering, deduplication, and send/server-echo reconciliation.
- Text, image, and audio message transport using the current visitor API.
- Human handoff, typing updates, and required pre-chat support.
- Prebuilt full-screen, launcher, embedded, bottom-sheet, dialog, and headless integration surfaces.
- Material UI defaults with server/host theme resolution, loading, empty, error, reconnecting, offline, and accessibility states.
- `WisperBotConfig.useApiColors` for switching between API-provided colors and the built-in WisperBot brand palette.
- Format-aware remote image rendering for SVG and Flutter-supported raster assets.
- Public API documentation and contributor guidance.

### Changed

- Aligned visitor requests with the Laravel widget API and removed unsupported realtime, identity-outcome, and unread state contracts.
- Reorganized internals into configuration, domain, application, data, and presentation boundaries without changing the public API.
- Clarified networking through named API endpoints, a central HTTP caller, and an operation-oriented widget remote data source.
- Updated the default Flutter chat UI to better match the WisperBot web widget.
- Increased bottom-sheet presentation height to 96% of the available safe height.
- Moved example widget key and API base URL configuration into a local `.env` file.
- Kept built-in copy in English while leaving localization delegates and label overrides as a pre-stable API task.
- Updated package/example dependency versions and Android example compile SDK, and removed generated iOS Flutter build files from version control.

### Fixed

- Corrected image/audio delivery to use the backend multipart upload format.
- Fixed duplicate outgoing bubbles by reconciling poll echoes with in-flight send responses.
- Removed routine `Sending` and `Sent` bubble labels while retaining internal delivery tracking and visible failed/unconfirmed states.
- Validated image/audio extension and MIME pairs, caption limits, byte limits, and native multipart edge `406` failures.
- Ensured required pre-chat submission is token-bound and does not persist submitted PII.
- Routed backend AI auto-replies through the queue so visitor sends can be acknowledged immediately.

### Documented

- Current backend contract and native domain-policy limitation.
