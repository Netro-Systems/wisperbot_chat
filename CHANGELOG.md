# Changelog

## 0.2.0 - 2026-10-07

This is a breaking release. See the migration table in the README when
upgrading from `0.1.x`.

### Added

- Added flat `WisperBotChat.initialize`, `identify`, `logout`, and `shutdown` APIs for a shared default runtime.
- Added `WisperBotChat.launcher()`, `view()`, and `screen()` presentation helpers.
- Added `registerVisitorOnAppLaunch`, which defaults to `true`, to initialization and headless-client options.
- Added direct configuration and an optional initial `user` to `WisperBotClient`.
- Notification permission gating now defaults to enabled; set `requireNotificationPermission: false` to opt out.
- Persisted sessions now include a redacted identity-profile fingerprint, preventing changed names, avatars, or custom fields from restoring stale visitor metadata.

### Changed

- Developers now pass configuration directly to `WisperBotChat.initialize`; the configuration object is internal.
- Moved visitor identity to `WisperBotChat.identify`; advanced runtimes can use `WisperBotClient(user: ...)` or `WisperBotChatController.updateUser`.
- Made OneSignal notification handlers and eager visitor registration internal to `WisperBotChat.initialize`.
- Made the prebuilt screen, embedded view, launcher, and modal facade use the shared runtime by default.
- Updated the example to initialize once and use config-free chat surfaces.
- Decoupled public launcher configuration loading from visitor registration, so API colors and placement load even when `registerVisitorOnAppLaunch` is `false`.

### Fixed

- Updated launcher configuration decoding to accept the JavaScript object wrapper returned by the public widget loader, allowing API colors to load before chat opens.
- Invalidated persisted identified sessions when profile data changes, preventing stale names, avatars, or custom fields from being restored on a later launch.

### Removed

- Removed `WisperBotLocation` and `WisperBotUser.location`; use `WisperBotUser.customFields` for optional metadata.
- Removed `WisperBotChat.initializeNotificationHandlers` and `WisperBotChat.registerVisitor`.
- Removed `WisperBotConfig` from the public API; identity and initialization options now belong to the runtime.
- Removed `WidgetOneSignalService` from the public package exports.
- Removed automatic country, city, coordinates, page-title, and page-URL payload generation; explicit `customFields` continue to pass through unchanged.

## 0.1.7 - 2026-10-04

### Added

- Made `http://`, `https://`, and `www.` links in message text tappable while preserving text selection and copying.
- Added feedback when a message link cannot be opened.

### Changed

- Foreground push notifications no longer display SDK SnackBars. Use `onForegroundNotification` for custom foreground handling.
- Retained `showInAppForegroundNotification` for source compatibility; its value is now ignored.

## 0.1.6 - 2026-09-28

### Added

- Added reusable, accessible starter-question buttons from session configuration below the welcome message.
- Added immediate post-send message refresh so deterministic replies appear without waiting for realtime delivery.
- Added persistent human-handoff waiting and connected states, including the agent name when available.

### Changed

- Documented that new integrations must use the widget's Mobile SDK key.

### Fixed

- Applied realtime message delivery/read status updates immediately and prevented out-of-order status downgrades.
- Kept realtime bot answers behind their in-flight visitor message so replies no longer flash above the question before send confirmation.
- Ignored malformed realtime delivery-status payloads through defensive decoding.
- Improved native audio playback compatibility and cleaned up temporary audio resources and stale preview loads.
- Improved chat initialization and secure-session storage recovery.
- Added Settings guidance when microphone permission remains denied on a later recording attempt.

## 0.1.4

### Changed

- Replaced timer-based foreground polling with Pusher as the primary live conversation transport.
- Removed `WisperBotPollingConfig` and `WisperBotConfig.polling`; retained bounded pull-to-refresh and initial history pagination without a periodic scheduler.
- Realtime connections now follow listener and application lifecycle demand and retry failed initial socket connections.

## 0.1.3

### Added

- Added `WisperBotConfig.lightStatusBarIcons` to use white status-bar content over dark or strongly colored headers in full-screen chat.
- Added lightweight widget-configuration preloading so launchers can resolve dashboard colors and placement without opening chat or requesting notification permission.
- Added custom attachment, microphone, send, document, camera, gallery, audio, close, and delete icon assets.

### Changed

- Redesigned the message composer into a compact, single-row layout inspired by modern messaging apps.
- The text field now starts at one line, expands horizontally on focus, and grows vertically only for multiline messages.
- Attachment, microphone, and send controls now share the compact field height and remain bottom-aligned while the field expands.
- Updated the attachment picker to use the new document, camera, gallery, and audio assets.
- Updated chat-header and pending-attachment close actions to use the new close asset, and recording cancellation to use the new delete asset.
- Updated README configuration and launcher behavior documentation.

### Fixed

- Fixed `WisperBotChatLauncher` briefly showing the fallback brand color before applying the API-provided color.
- Fixed API colors not appearing on notification-gated launchers until chat had been opened once.
- Fixed the enabled send icon retaining its dark disabled color instead of using the contrasting `onPrimary` color.
- Preserved a 48 dp accessible send target while keeping the visible button aligned with the 42 px compact composer.

## 0.1.2

### Added

- **OneSignal Push Notifications**: Added `oneSignalAppId` configuration in `WisperBotConfig` and push notification handling with automatic chat navigation on notification tap (`WisperBotChat.handleNotificationClick`, `WisperBotChat.openChatFromNotification`).
- **Document & File Attachments**: Added cross-platform document picking support (`file_selector`) alongside camera and gallery image attachments.
- **Attachment Picker Sheet**: Introduced interactive attachment bottom sheet for selecting photos, camera captures, or documents.
- **Rich Document & File Preview**: Enhanced message bubbles to render document icons, file sizes, file extensions, and tap-to-open handlers.

### Changed

- Enhanced pre-chat form validation with robust field requirements checking.
- Refined message composer bottom padding and attachment action layout.
- Updated example application to demonstrate document attachments and OneSignal configuration.
- Updated documentation and presentation screenshots.

## 0.1.1

### Documentation & Assets

- Reorganized README with a developer-first flow, quick start, and platform setup instructions.
- Added a full `WisperBotConfig` property reference table and example snippets.
- Added visual UI showcase screenshots for all presentation styles (full screen, bottom sheet, dialog, floating launcher, embedded view).

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
