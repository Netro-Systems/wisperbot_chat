# WisperBot Chat SDK example

This app demonstrates the full-screen facade, floating launcher, embedded view,
bottom sheet, dialog, image/document upload, and microphone recording. The SDK
handles media with its built-in adapter; the app does not create a custom adapter.
One `WisperBotChat.initialize` call owns notifications, visitor registration,
navigation, and the controller shared by every chat integration.

For push troubleshooting, filter Android Studio/Flutter debug output for
`WisperBot push`. Logs report FCM token availability, registration start/success,
HTTP failures, retries, foreground receipt and background notification taps.
They exclude tokens, visitor details and message text. Background display is
handled by the OS, so background receipt itself does not produce a Dart log.
On the server, filter Laravel logs for `Widget FCM` and `FCM` to follow the support
reply, subscription count, queue worker and provider result. Backend changes must
be deployed and queue workers restarted; rebuild the app for SDK changes.

The SDK-provided floating launcher displays an unread dot automatically. For
an application-owned button or design, wrap its visible child with
`WisperBotChat.badge(child: ...)`; set `showCount: true` for a numeric badge.
Opening chat through `WisperBotChat.open(context)` marks visible agent messages
read and clears the badge. Badge updates use the existing realtime connection
and require no separate backend integration. See the package's
[unread badge guide](../doc/unread-badges.md) for customization and the complete
option reference.

1. Copy `.env.example` to `.env`.
2. Put the SDK key from **Widget Integrations → Mobile app** in `WISPERBOT_WIDGET_KEY`. The website embed key can start chat sessions but cannot register FCM push tokens (HTTP 403). Change `WISPERBOT_API_BASE_URL` only for staging or a self-hosted API.
   For push, configure native Firebase files using the project authorized by the global
   **Super Admin → Integrations → Firebase Cloud Messaging** configuration, and set
   `FCM_ENABLED=true`. No workspace credential upload is required. Leave it false to run
   the example without push. Production hosts normally initialize Firebase using the
   generated `DefaultFirebaseOptions.currentPlatform` before initializing WisperBot.
   This example selects Firebase Core 3/Messaging 15 to retain its iOS 13 target.

The Android example includes internet and microphone permissions and uses the
Flutter tool's supported minimum SDK for audio recording. The iOS example
includes photo-library and microphone usage descriptions. Voice messages are
captured as a PCM16 stream and wrapped in a WAV container before upload because
the recorder plugin does not support WAV directly in stream mode. The iOS/macOS projects include the Keychain
Sharing entitlements required by the default secure session store. Flutter
bundles `.env` as an application asset, so it is suitable only for public client
configuration such as the widget key and API base URL. Never put identity
secrets, workspace credentials, or management API credentials in it.

The example identifies one sample user directly after initialization. In a real
app, call `WisperBotChat.identify` only after the actual signed-in profile is
available, and use a stable application user ID:

```dart
await WisperBotChat.identify(
  WisperBotUser(
    userId: profile.id,
    name: profile.name,
    email: profile.email,
  ),
);
```

Do not send placeholder names or temporary email addresses. If profile loading
happens after the first app frame, initialize with
`registerVisitorOnAppLaunch: false`; visual launcher configuration still loads,
and the identified session starts when chat is opened.

For a guest whose name is known, identify with only
`WisperBotUser(name: 'Guest User')`. WisperBot restores that guest on normal
app restarts. Uninstalling and reinstalling creates a new guest, while a
logged-in user can recover server history on any installation through `userId`.
HMAC identity verification is optional and disabled by default.

The example uses the SDK’s built-in `https://wisperbot.com` server address. It renders
the first screen before identifying its sample user, so Android can foreground the
activity before the session request. A network failure can recover when the app
resumes; no Firebase or server URL change is needed for that recovery.
