# WisperBot Chat SDK example

This app demonstrates the full-screen facade, floating launcher, embedded view,
bottom sheet, dialog, gallery-image upload, and microphone recording. Media
plugins live in the example and are connected through `WisperBotMediaAdapter`,
so applications can choose their own maintained picker/recorder packages
without adding them to the core SDK.

1. Copy `.env.example` to `.env`.
2. Put your public widget key in `WISPERBOT_WIDGET_KEY`. Change `WISPERBOT_API_BASE_URL` only for staging or a self-hosted API.
3. For native runs, use a widget without a browser-domain allowlist; the SDK
   does not spoof browser origin headers. Required name/email pre-chat is
   supported by the example and SDK. The production LiteSpeed/ModSecurity
   configuration must narrowly allow multipart `POST /widget/v1/messages`;
   otherwise the SDK reports `WisperBotErrorCode.edgeRejected` for the HTML
   `406` generated before Laravel.
4. Run `flutter pub get`, then `flutter run` from this directory. Android, iOS,
   and web runners are included.

The Android example includes internet and microphone permissions and uses the
Flutter tool's supported minimum SDK for audio recording. The iOS example
includes photo-library and microphone usage descriptions. The iOS/macOS projects include the Keychain
Sharing entitlements required by the default secure session store. Flutter
bundles `.env` as an application asset, so it is suitable only for public client
configuration such as the widget key and API base URL. Never put identity
secrets, workspace credentials, or management API credentials in it.
