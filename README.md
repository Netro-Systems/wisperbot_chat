# Wisperbot chat

![WisperBot](assets/images/wb_horizontal_white.png)

![pub version](https://img.shields.io/pub/v/wisperbot_chat?label=wisperbot_chat)
![last commit](https://img.shields.io/github/last-commit/Netro-Systems/wisperbot_chat)
![license](https://img.shields.io/badge/license-MIT-green)

A customizable, battery-efficient Flutter SDK for embedding WisperBot customer support chat into mobile, web, and desktop apps. It provides identity-scoped visitor sessions, real-time messaging, foreground polling, prebuilt customizable UI, and push notifications.

---

## Capabilities & Platform Support

| Capability | Android / iOS | Web | macOS / Windows / Linux |
|---|:---:|:---:|:---:|
| **Anonymous & Signed-User Sessions** | ✅ Yes | ✅ Yes* | ✅ Yes |
| **OneSignal Push Notifications** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Text, Image & Audio Messaging** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Foreground Polling & Sync** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Typing Indicators & Human Handoff** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Prebuilt UI (Screens, Sheets, Dialogs, Launchers)** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Required Pre-Chat Lead Forms** | ✅ Yes | ✅ Yes | ✅ Yes |

*\* Web secure storage requires HTTPS (or localhost during development) and is scoped to the browser origin.*

---

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  wisperbot_chat: ^0.1.3
```

Or run:

```bash
flutter pub add wisperbot_chat
```

### Platform Requirements

* **Android**: Set `minSdk = 23` in `android/app/build.gradle` (required by `flutter_secure_storage`) and ensure `INTERNET` permission is granted:
  ```kotlin
  defaultConfig {
      minSdk = 23
  }
  ```
* **iOS & macOS**: Enable **Keychain Sharing** in Xcode and include a `keychain-access-groups` entitlement. The runnable [example](example) contains the required configuration.
* **Web**: Deploy over HTTPS (browser session storage inherits the origin's security).

---

## Quick Start

Open a functional chat interface with just a few lines of code using your public **Widget Key**:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void openSupportChat(BuildContext context) async {
  final config = WisperBotConfig(widgetKey: 'YOUR_WIDGET_KEY');
  await WisperBotChat.open(context, config: config);
}
```

> [!NOTE]
> The `widgetKey` is a public routing identifier, not a secret. Never bundle WisperBot management credentials or widget secret keys in client applications.

---

## Integration Styles

WisperBot provides multiple ready-to-use presentation modes to fit seamlessly into any app workflow:

![Integration Options Showcase](screenshot/test_home.png)

### 1. Full Screen
An immersive, dedicated support page with app bar navigation:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

void openFullScreen(BuildContext context, WisperBotConfig config) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => WisperBotChatScreen(config: config),
    ),
  );
}
```

![Full Screen Chat](screenshot/full_screen.png)

### 2. Modal Bottom Sheet
Keeps the current screen in context while sliding up the chat interface:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

Future<void> openBottomSheet(BuildContext context, WisperBotConfig config) async {
  await WisperBotChat.open(
    context,
    config: config,
    presentation: WisperBotPresentation.bottomSheet,
  );
}
```

![Bottom Sheet Chat](screenshot/bottom_sheet.png)

### 3. Dialog Popup
A compact, centered chat window ideal for tablets, desktops, or web:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

Future<void> openDialog(BuildContext context, WisperBotConfig config) async {
  await WisperBotChat.open(
    context,
    config: config,
    presentation: WisperBotPresentation.dialog,
  );
}
```

![Dialog Chat](screenshot/floating.png)

### 4. Floating Launcher
An expandable floating action button that overlays your screen:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

Widget buildFloatingLauncher(WisperBotConfig config) {
  return Stack(
    children: [
      const Placeholder(), // Application content
      WisperBotChatLauncher(config: config),
    ],
  );
}
```

![Floating Launcher](screenshot/floating_launcher.png)

When `useApiColors` is enabled, the launcher waits for the dashboard widget
configuration before appearing. This prevents the fallback brand color from
flashing before the API color is applied.

### 5. Embedded View
Place the chat view directly inside an existing layout, drawer, or split-view:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

Widget buildEmbeddedChat(WisperBotConfig config) {
  return WisperBotChatView(
    config: config,
    showHeader: true,
  );
}
```

![Embedded Chat View](screenshot/embedded.png)

### 6. Headless & Custom UI
Take full programmatic control with `WisperBotChatController`:

```dart
import 'package:wisperbot_chat/wisperbot_chat.dart';

Future<void> runHeadlessChat(WisperBotConfig config) async {
  final client = WisperBotClient(config: config);
  final controller = WisperBotChatController(client: client);

  // Listen to state changes
  final subscription = controller.states.listen((state) {
    print('Phase: ${state.phase}, Messages: ${state.messages.length}');
  });

  await controller.initialize();
  await controller.sendText('Hello, I need help!');

  // Cleanup
  await subscription.cancel();
  await controller.dispose();
  await client.close();
}
```

---

## Configuration Reference

`WisperBotConfig` accepts the following options:

| Property | Type | Default | Description |
|---|---|---|---|
| `widgetKey` | `String` | *(required)* | Public routing identifier issued by the WisperBot dashboard. |
| `apiBaseUrl` | `String` | `'https://wisperbot.com'` | Base origin endpoint for widget API requests (`/widget/v1/*`). |
| `user` | `WisperBotUser?` | `null` | Visitor identity, profile data, and HMAC signature for verified users. |
| `theme` | `WisperBotThemeData?` | `null` | Presentation overrides for colors, bubble radius, spacing, and brightness. |
| `useApiColors` | `bool` | `true` | When true, applies the dashboard-configured branding palette automatically. |
| `lightStatusBarIcons` | `bool` | `false` | Uses white status-bar icons and text in full-screen chat. Enable it for dark or strongly colored headers. |
| `presentation` | `WisperBotPresentation` | `WisperBotPresentation.fullScreen` | Default modal style (`fullScreen`, `bottomSheet`, or `dialog`) used by `WisperBotChat.open`. |
| `enableTyping` | `bool` | `true` | Whether the controller publishes throttled visitor typing updates. |
| `mediaAdapter` | `WisperBotMediaAdapter?` | `null` | Optional bridge for image selection and voice recording plugins. |
| `polling` | `WisperBotPollingConfig` | `const WisperBotPollingConfig()` | Intervals for active (`3s`), idle (`8s`), and failure backoff (`30s`) foreground polling. |
| `diagnostics` | `WisperBotDiagnosticsCallback?` | `null` | Callback receiving redacted operational metrics and lifecycle events. |
| `oneSignalAppId` | `String?` | `null` | OneSignal App ID used for push notification registration. |
| `enableOneSignal` | `bool` | `true` | Whether device push notification tokens are registered on session start. |
| `requireNotificationPermission` | `bool` | `false` | Requires notification permission before chat starts on Android or iOS. The launcher can still preload visual configuration. |
| `sessionStore` | `WisperBotSessionStore?` | `null` | Optional custom storage for identity-scoped session credentials. |

---

## Key Features

### 👤 Verified & Authenticated Users
To associate chat sessions with registered users in your application, provide a `WisperBotUser` along with an HMAC signature computed on your backend:

```dart
import 'package:wisperbot_chat/wisperbot_chat.dart';

final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  user: WisperBotUser(
    externalId: 'user_123',
    name: 'John Doe',
    email: 'user@example.com',
    signature: 'backend_hmac_signature',
  ),
);
```

#### Switching Accounts & Logout
* **Switch user**: Call `controller.updateUser(newUser)` when switching accounts.
* **Logout**: Call `controller.updateUser(null)` on logout to wipe active credentials and clear local conversation state securely.

---

### 🎨 Colors & Theming
By default, the SDK uses the color palette configured in your WisperBot dashboard (`useApiColors: true`). 

To customize colors locally or use custom themes:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  useApiColors: false, // Disables server palette
  lightStatusBarIcons: true, // White status-bar content in full-screen chat
  theme: const WisperBotThemeData(
    primaryColor: Color(0xFF087F5B),
    visitorBubbleColor: Color(0xFF087F5B),
    agentBubbleColor: Color(0xFFE9ECEF),
    borderRadius: 16.0,
  ),
);
```

`lightStatusBarIcons` affects full-screen chat only. Leave it `false` for dark
status-bar content on light headers. Set it to `true` for white status-bar
content on dark or strongly colored headers.

---

### 🔔 Push Notifications
The SDK provides built-in OneSignal push notification integration so visitors receive notifications when agents reply.

To require notification permission before support chat starts on Android or iOS:

```dart
final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
  oneSignalAppId: 'YOUR_ONESIGNAL_APP_ID',
  requireNotificationPermission: true,
);
```

Tapping the launcher or calling `WisperBotChat.open` requests the native permission
prompt when notifications are disabled and the OS permits a request. Chat starts
only after permission is granted. If another prompt cannot be shown, a snackbar
says: "Enable notifications from settings to use the support feature."
After enabling notifications in settings, the user can tap chat again.
The launcher preloads visual widget configuration for API colors and placement,
but defers chat initialization and the notification permission prompt until
tapped when this option is enabled.
Direct screens, embedded views, and headless controllers enforce the same session
requirement; custom UI should handle `WisperBotErrorCode.notificationPermission`.
The option defaults to `false` and requires OneSignal to be enabled with an app ID.
Open chat from a context with a `ScaffoldMessenger` to show the snackbar.

Initialize notification handlers in `main()`:

```dart
import 'package:flutter/material.dart';
import 'package:wisperbot_chat/wisperbot_chat.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = WisperBotConfig(
    widgetKey: 'YOUR_WIDGET_KEY',
    user: const WisperBotUser(name: 'Demo User', email: 'user@demo.com'),
  );

  WisperBotChat.initializeNotificationHandlers(
    config: config,
    navigatorKey: navigatorKey,
  );

  runApp(MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()));
}
```
When a notification is tapped, the SDK automatically opens the chatbox.

---

### 📷 Media & Voice Attachments
The prebuilt composer includes image picking, document picking, and voice recording
using the SDK's built-in media adapter. No custom adapter is needed:

```dart
import 'package:wisperbot_chat/wisperbot_chat.dart';

final config = WisperBotConfig(
  widgetKey: 'YOUR_WIDGET_KEY',
);
```
The app must provide the platform permission declarations for the media features
it uses, including iOS photo-library and microphone usage descriptions. See the
[example](example) app for platform setup.

`mediaAdapter` is an optional override for apps that need custom picker or recording
behavior. Most integrations should leave it unset.

---

### 📝 Pre-Chat Forms
When a widget requires pre-chat information (such as name or email), the built-in UI collects and submits the required fields automatically before initiating chat.

For headless integrations, submit manually via:
```dart
import 'package:wisperbot_chat/wisperbot_chat.dart';

Future<void> submitLead(WisperBotChatController controller) async {
  await controller.submitPreChat(
    const WisperBotPreChatData(name: 'Jane Doe', email: 'jane@example.com'),
  );
}
```

---

## Delivery & Reliability Behavior

* **Platform Security**: Visitor tokens are bearer credentials persisted via `WisperBotSessionStore` using platform-native secure storage (`flutter_secure_storage`).
* **Authoritative Confirmation**: Messages transition from `pending` to `sent` only upon server receipt and ID issuance.
* **Network Failures & Unconfirmed State**: If a request disconnects or times out before receiving a response, the message is marked `unconfirmed` rather than failed, avoiding duplicate message sends.
* **Battery-Efficient Sync**: Foreground polling synchronizes replies and pauses automatically when the application is backgrounded or when chat is closed.
* **Safe Diagnostics**: Diagnostic callbacks emit strictly redacted operational telemetry (durations, error codes, HTTP statuses) without logging PII, bearer tokens, or message content.

---

## Development & Testing

```bash
# Get dependencies
flutter pub get

# Format code
dart format --output=none --set-exit-if-changed .

# Run static analysis
flutter analyze

# Run unit tests
flutter test
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
