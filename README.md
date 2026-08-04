# wisperbot_chat

`wisperbot_chat` is a Flutter package for WisperBot's customer-facing chat. It owns secure visitor sessions, public widget API communication, realtime delivery with polling recovery, message reconciliation, lifecycle handling, typed state and errors, and an optional Material UI.

This is a `0.1.0-dev.1` preview. Use a controlled widget without a domain allowlist or required pre-chat until the corresponding native-client backend policy and configuration-bootstrap endpoints are available.

## Quick start

Add the package and open chat with a public widget key:

```dart
import 'package:wisperbot_chat/wisperbot_chat.dart';

final config = WisperBotConfig(widgetKey: 'YOUR_WIDGET_KEY');

await WisperBotChat.open(context, config: config);
```

The widget key routes chat and is not a secret. Never put WisperBot management credentials or a widget identity secret in a Flutter app.

## Installation

The preview requires Flutter 3.24 or newer (Dart 3.5 or newer).

Until the preview is published, use a Git or local path dependency:

```yaml
dependencies:
  wisperbot_chat:
    path: ../wisperbot_chat
```

Android apps must use min SDK 23 because the default session store uses `flutter_secure_storage`:

```kotlin
defaultConfig {
    minSdk = 23
}
```

Production apps also need Android's `INTERNET` permission. Debug-only local HTTP endpoints may require Android cleartext or Apple transport-security development configuration; non-debug SDK builds require HTTPS.

On iOS and macOS, enable Keychain Sharing and include a `keychain-access-groups` entitlement. The runnable [example](example/) contains the required configuration. Web deployments must use HTTPS (or localhost during development); browser session storage inherits the browser origin's security and backup behavior.

## Integration styles

Full screen:

```dart
Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => WisperBotChatScreen(config: config),
  ),
);
```

Floating launcher:

```dart
Stack(
  children: [
    const ApplicationContent(),
    WisperBotChatLauncher(config: config),
  ],
)
```

Embedded:

```dart
WisperBotChatView(config: config, showHeader: true)
```

Bottom sheet or dialog:

```dart
await WisperBotChat.open(
  context,
  config: config,
  presentation: WisperBotPresentation.bottomSheet,
);
```

Headless/custom UI:

```dart
final client = WisperBotClient(config: config);
final controller = WisperBotChatController(client: client);
final states = controller.states.listen(renderChatState);

await controller.initialize();
await controller.sendText('Hello');

await states.cancel();
await controller.dispose();
await client.close();
```

When a view, screen, or launcher creates its controller, it owns and disposes the runtime. When you supply a controller, you retain ownership.

## Colors and branding

API colors are enabled by default. Disable them to use WisperBot's built-in
orange brand palette:

```dart
final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false,
);
```

Custom theme colors always take precedence, whether API colors are enabled or
not:

```dart
final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false,
  theme: const WisperBotThemeData(
    primaryColor: Color(0xFF087F5B),
  ),
);
```

## Verified users

Generate the HMAC signature on your server. The SDK must never receive the widget identity secret.

```dart
final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  user: WisperBotUser(
    externalId: signedInUser.id,
    name: signedInUser.displayName,
    signature: signatureFetchedFromYourBackend,
  ),
);
```

Call `controller.updateUser(...)` whenever the host app switches accounts, and `controller.updateUser(null)` on logout. Sessions are securely isolated by canonical API base URL, widget key, and identity scope.

Anonymous and correctly signed identities persist across launches. Unsigned profile-only sessions stay in memory so an unverified display name or email cannot become a durable identity key or leave unreachable secure-storage records.

## Current capabilities

| Capability | Android/iOS | Web | macOS/Windows/Linux |
|---|---:|---:|---:|
| Anonymous and signed-user sessions | Yes | Yes* | Yes |
| Text, image/audio transport | Yes | Yes | Yes |
| Pusher realtime with polling recovery | Yes | Yes | Polling fallback |
| Typing and human handoff | Yes | Yes | Yes |
| Prebuilt screen/view/launcher/modal UI | Yes | Yes | Yes |
| Backward pagination and unread/read state | Backend pending | Backend pending | Backend pending |
| Push notifications | Not included | Not included | Not included |
| Required pre-chat | Bootstrap endpoint pending | Bootstrap endpoint pending | Bootstrap endpoint pending |
| Widget domain allowlist from native apps | Native policy pending | Supported by browser origin | Native policy pending |

\* Web secure storage requires HTTPS or localhost and is scoped to the browser origin.

The core upload API accepts validated bytes through `WisperBotUpload`. Supply a
`WisperBotMediaAdapter` in `WisperBotConfig` to enable the default composer's
image and microphone controls while keeping picker/recorder plugins out of the
core runtime. The example app contains a working `image_picker` + `record`
adapter.

## Delivery and error behavior

- Visitor tokens are bearer credentials stored through `WisperBotSessionStore`; the default implementation uses secure platform storage.
- A send becomes `sent` only after a server response supplies a message ID.
- A disconnected or timed-out send becomes `unconfirmed` and is not automatically retried, because the current backend has no client idempotency key.
- Pusher delivers new bot/human messages immediately when the backend advertises realtime. A poll runs after subscription/reconnection and every 60 seconds while connected; normal polling resumes whenever realtime is unavailable.
- Realtime events and poll responses are ordered and deduplicated by server ID. Only session/poll batches advance the receive cursor, preventing missed gaps.
- Required pre-chat is surfaced as a typed configuration failure instead of silently creating the wrong visitor identity.
- Diagnostics are structured and redacted; tokens, signatures, PII, message bodies, and attachment URLs are never included.

## Development

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

The deeper contracts live in [PROJECT_GOAL.md](docs/PROJECT_GOAL.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [DESIGN_SYSTEM.md](docs/DESIGN_SYSTEM.md), and [API.md](docs/API.md).
