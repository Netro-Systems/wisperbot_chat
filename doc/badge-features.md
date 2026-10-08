# WisperBot unread badge features

The unread badge works through WisperBot's existing realtime connection. No
additional backend integration is required.

## 1. Automatic badge on the WisperBot launcher

The built-in launcher shows an unread dot automatically when an agent sends a
message.

```dart
Scaffold(
  floatingActionButton: WisperBotChat.launcher(),
)
```

## 2. Badge for any custom widget

Wrap any icon, button, image, container, or custom widget with
`WisperBotChat.badge`.

```dart
IconButton(
  onPressed: () => WisperBotChat.open(context),
  icon: WisperBotChat.badge(
    child: const Icon(Icons.chat),
  ),
)
```

## 3. Unread count

Use `showCount: true` to show the number of unread messages instead of a dot.

```dart
WisperBotChat.badge(
  showCount: true,
  child: const Icon(Icons.chat),
)
```

Counts from 1 through 99 are circular by default. A larger count is shown as
`99+` in a pill.

## 4. Badge color and text customization

```dart
WisperBotChat.badge(
  showCount: true,
  backgroundColor: Colors.pink,
  textColor: Colors.white,
  child: const Icon(Icons.chat),
)
```

## 5. Badge size and typography

Use `smallSize` for a dot and `largeSize` for a badge containing text.

```dart
WisperBotChat.badge(
  showCount: true,
  largeSize: 16,
  textStyle: const TextStyle(fontSize: 10, height: 1),
  child: const Icon(Icons.chat),
)
```

## 6. Badge position

Use `alignment` to select an anchor and `offset` to fine-tune the position.

```dart
WisperBotChat.badge(
  alignment: Alignment.topRight,
  offset: const Offset(7, -7),
  child: const Icon(Icons.chat),
)
```

Positive x moves the badge right. Negative y moves it up.

## 7. Maximum displayed count

```dart
WisperBotChat.badge(
  showCount: true,
  maxCount: 9,
  child: const Icon(Icons.chat),
)
```

When there are more than 9 unread messages, the badge displays `9+`.

## 8. Custom badge label

Use `labelBuilder` when the badge should contain custom content.

```dart
WisperBotChat.badge(
  labelBuilder: (context, count) => Text('$count new'),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  child: const Icon(Icons.chat),
)
```

## 9. Built-in launcher customization

The built-in launcher provides the same options with a `badge` prefix.

```dart
WisperBotChat.launcher(
  badgeShowCount: true,
  badgeMaxCount: 99,
  badgeBackgroundColor: Colors.pink,
  badgeTextColor: Colors.white,
  badgeLargeSize: 16,
  badgeOffset: const Offset(8, -8),
)
```

## 10. Disable the launcher badge

```dart
WisperBotChat.launcher(
  showBadge: false,
)
```

## 11. Automatic badge clearing

Opening the shared chat marks visible agent messages as read and clears the
badge automatically.

```dart
onPressed: () => WisperBotChat.open(context)
```

## 12. Completely custom unread UI

For advanced designs, listen to the shared unread count directly.

```dart
ValueListenableBuilder<int>(
  valueListenable: WisperBotChat.unreadCount,
  builder: (context, count, child) {
    return MyCustomButton(
      showIndicator: count > 0,
      onPressed: () => WisperBotChat.open(context),
    );
  },
)
```

Most applications do not need this. `WisperBotChat.badge` already manages the
listener automatically.

## 13. Headless controller support

Custom chat implementations can read unread state from the controller.

```dart
final count = controller.state.unreadCount;
final hasUnread = controller.state.hasUnreadMessages;
```

When the custom chat becomes visible, mark the messages as read:

```dart
await controller.markRead();
```

## 14. Reliable unread state

The SDK also handles these cases automatically:

- Incoming agent messages remain unread until chat is viewed.
- Visitor messages and activity events are not counted.
- Returning to the app refreshes messages and restores realtime updates.
- Old refresh or realtime data cannot change a read message back to unread.
- Logout and SDK shutdown reset the shared unread count.

For complete option descriptions and troubleshooting, see
[Unread badges](unread-badges.md).
