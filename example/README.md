# WisperBot Chat SDK example

This app demonstrates the full-screen facade, floating launcher, embedded view,
bottom sheet, dialog, image/document upload, and microphone recording. The SDK
handles media with its built-in adapter; the app does not create a custom adapter.
One `WisperBotChat.initialize` call owns notifications, visitor registration,
navigation, and the controller shared by every chat integration.

The SDK-provided floating launcher displays an unread dot automatically. For
an application-owned button or design, wrap its visible child with
`WisperBotChat.badge(child: ...)`; set `showCount: true` for a numeric badge.
Opening chat through `WisperBotChat.open(context)` marks visible agent messages
read and clears the badge. Badge updates use the existing realtime connection
and require no separate backend integration. See the package's
[unread badge guide](../docs/unread-badges.md) for customization and the complete
option reference.

1. Copy `.env.example` to `.env`.
2. Put your public widget key in `WISPERBOT_WIDGET_KEY`. Change `WISPERBOT_API_BASE_URL` only for staging or a self-hosted API.
   Set `ONESIGNAL_APP_ID` for Android/iOS notification permission gating. The
   example enables the requirement only when this value is present, so the
   default empty value also works for web and notification-free testing.
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
includes photo-library and microphone usage descriptions. Voice messages are
captured as a PCM16 stream and wrapped in a WAV container before upload because
the recorder plugin does not support WAV directly in stream mode. The iOS/macOS projects include the Keychain
Sharing entitlements required by the default secure session store. Flutter
bundles `.env` as an application asset, so it is suitable only for public client
configuration such as the widget key and API base URL. Never put identity
secrets, workspace credentials, or management API credentials in it.

The example starts anonymously and deliberately does not identify a fake demo
visitor. In a real app, call `WisperBotChat.identify` only after the actual
signed-in profile is available, and use a stable application user ID:

```dart
await WisperBotChat.identify(
  WisperBotUser(
    externalId: profile.id,
    name: profile.name,
    email: profile.email,
  ),
);
```

Do not send placeholder names or temporary email addresses. If profile loading
happens after the first app frame, initialize with
`registerVisitorOnAppLaunch: false`; visual launcher configuration still loads,
and the identified session starts when chat is opened.
