# WisperBot Chat SDK example

This app demonstrates the full-screen facade, floating launcher, embedded view, bottom sheet, and dialog integrations.

1. Replace `YOUR_WIDGET_KEY` in `lib/main.dart` with a controlled staging widget key.
2. Ensure the widget does not require pre-chat or a browser-domain allowlist while the native-client backend gates remain pending.
3. Run `flutter run` from this directory.

The Android project includes internet access and inherits the Flutter tool's supported minimum SDK. The iOS/macOS projects include the Keychain Sharing entitlements required by the default secure session store. No production credentials or personal data belong in this example.
