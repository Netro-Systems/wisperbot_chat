# WisperBot Chat SDK example

This app demonstrates the full-screen facade, floating launcher, embedded view,
bottom sheet, dialog, gallery-image upload, and microphone recording. Media
plugins live in the example and are connected through `WisperBotMediaAdapter`,
so applications can choose their own maintained picker/recorder packages
without adding them to the core SDK.

1. Copy `.env.example` to `.env`.
2. Put your public widget key in `WISPERBOT_WIDGET_KEY`. Change `WISPERBOT_API_BASE_URL` only for staging or a self-hosted API.
3. Ensure the widget does not require pre-chat or a browser-domain allowlist while the native-client backend gates remain pending.
4. Run `flutter pub get`, then `flutter run` from this directory.

The Android example includes internet and microphone permissions and uses the
Flutter tool's supported minimum SDK for audio recording. The iOS example
includes photo-library and microphone usage descriptions. The iOS/macOS projects include the Keychain
Sharing entitlements required by the default secure session store. Flutter
bundles `.env` as an application asset, so it is suitable only for public client
configuration such as the widget key and API base URL. Never put identity
secrets, workspace credentials, or management API credentials in it.
