# Unread badges

WisperBot unread badges tell users that an agent has replied even when a push
notification was missed. The SDK receives the message through its existing
realtime connection, updates the badge, and removes it after the conversation
is viewed. This feature does not require a new backend endpoint or separate
Pusher integration.

## Choose your integration

| Your UI | Recommended API | Work required |
|---|---|---|
| WisperBot floating launcher | `WisperBotChat.launcher()` | None; the dot is enabled by default. |
| Application-owned button or design | `WisperBotChat.badge(child: ...)` | Wrap the widget that should display the badge. |
| Completely custom indicator | `WisperBotChat.unreadCount` | Listen to the count and render your own UI. |
| Explicit/headless controller | `controller.state.unreadCount` | Listen to controller state and call `markRead()` when your UI is viewed. |

## Beginner: use the built-in launcher

The built-in launcher already includes the unread dot:

```dart
Scaffold(
  floatingActionButton: WisperBotChat.launcher(),
)
```

There is nothing else to connect. An incoming unread agent message shows the
dot, and opening chat clears it after the message is marked read.

To display a number instead:

```dart
Scaffold(
  floatingActionButton: WisperBotChat.launcher(
    badgeShowCount: true,
  ),
)
```

To turn the launcher's badge off:

```dart
WisperBotChat.launcher(showBadge: false)
```

## Beginner: add a badge to your own button

Keep your existing `onPressed` and wrap only the visible widget:

```dart
IconButton(
  tooltip: 'Open chat',
  onPressed: () => WisperBotChat.open(context),
  icon: WisperBotChat.badge(
    child: const Icon(Icons.chat),
  ),
)
```

`WisperBotChat.badge` is not limited to icons or buttons. Its `child` can be a
container, image, card, custom button, or any other widget:

```dart
WisperBotChat.badge(
  child: MyCustomChatButton(
    onPressed: () => WisperBotChat.open(context),
  ),
)
```

The wrapper listens to the shared WisperBot runtime. It does not replace the
child's gestures, and it does not require a `ValueListenableBuilder`.

## Common customizations

### Show the unread count

```dart
WisperBotChat.badge(
  showCount: true,
  child: const Icon(Icons.chat),
)
```

With the default `maxCount: 99`, counts from 1 through 99 are circular. A count
above the maximum is displayed as `99+` in a pill.

### Change colors and size

```dart
WisperBotChat.badge(
  showCount: true,
  backgroundColor: Colors.pink,
  textColor: Colors.white,
  largeSize: 16,
  textStyle: const TextStyle(fontSize: 10, height: 1),
  child: const Icon(Icons.chat),
)
```

Use a realistic `largeSize` for the selected text. Values around 14–20 logical
pixels work well for most icon buttons. Extremely small values cannot display
a readable number.

### Move the badge

```dart
WisperBotChat.badge(
  alignment: Alignment.topRight,
  offset: const Offset(7, -7),
  child: const Icon(Icons.chat),
)
```

`alignment` first anchors the indicator to the wrapped child's bounds. `offset`
then moves it from that position:

- Positive `dx` moves right; negative `dx` moves left.
- Positive `dy` moves down; negative `dy` moves up.
- For a 14-pixel circle, `Offset(7, -7)` places its center approximately on
  the child's top-right corner.

The badge can paint outside the child without changing the child's layout
size. If an ancestor clips its children, give the surrounding layout enough
space or disable clipping on that ancestor.

### Build a custom label

`labelBuilder` receives the actual unread count. It takes precedence over the
standard dot and numeric label:

```dart
WisperBotChat.badge(
  labelBuilder: (context, unreadCount) => Text('$unreadCount new'),
  padding: const EdgeInsets.symmetric(horizontal: 6),
  backgroundColor: Colors.deepPurple,
  textColor: Colors.white,
  child: const Icon(Icons.chat),
)
```

Custom labels use an expanding pill so longer content can fit.

## `WisperBotChat.badge` option reference

| Option | Type | Default | Behavior |
|---|---|---|---|
| `child` | `Widget` | Required | Widget that the indicator is anchored to. Its gestures and layout are preserved. |
| `key` | `Key?` | `null` | Optional key for the wrapper widget. |
| `showCount` | `bool` | `false` | Shows the numeric unread count instead of a dot. Ignored when `labelBuilder` supplies custom content. |
| `maxCount` | `int` | `99` | Largest count shown directly. A larger value is displayed as `<maxCount>+`. |
| `labelBuilder` | `Widget Function(BuildContext, int)?` | `null` | Builds custom badge content from the actual unread count. Takes precedence over `showCount`. |
| `backgroundColor` | `Color?` | Theme error color | Fill color of the dot, circle, or pill. |
| `textColor` | `Color?` | Theme on-error color | Count or custom-label foreground color supplied through `DefaultTextStyle`. |
| `smallSize` | `double?` | `8` | Diameter of a dot badge. It does not control a badge containing text. |
| `largeSize` | `double?` | `16` | Height of a labeled badge and diameter of normal one- or two-digit counts. |
| `textStyle` | `TextStyle?` | Theme label-small style | Typography for numeric and custom labels. `textColor` overrides its color. |
| `padding` | `EdgeInsetsGeometry?` | No circle padding; 4 horizontal for pills | Inner spacing for label content. Pills can expand horizontally to include it. |
| `alignment` | `AlignmentGeometry?` | `AlignmentDirectional.topEnd` | Anchor position relative to the wrapped child. Directional alignment respects text direction. |
| `offset` | `Offset?` | `Offset.zero` | Final translation after alignment. Positive x is right; positive y is down. |

The wrapper renders no indicator when the unread count is zero.

## Built-in launcher badge option reference

`WisperBotChat.launcher` exposes equivalent settings with a `badge` prefix:

| Launcher option | Wrapper equivalent | Default | Behavior |
|---|---|---|---|
| `showBadge` | — | `true` | Enables or disables the launcher's unread indicator. |
| `badgeShowCount` | `showCount` | `false` | Selects numeric count mode instead of dot mode. |
| `badgeMaxCount` | `maxCount` | `99` | Controls when the count changes to a plus suffix. |
| `badgeLabelBuilder` | `labelBuilder` | `null` | Builds custom label content from the unread count. |
| `badgeBackgroundColor` | `backgroundColor` | Resolved error color | Sets the indicator fill color. |
| `badgeTextColor` | `textColor` | Theme on-error color | Sets the label foreground color. |
| `badgeSmallSize` | `smallSize` | `14` | Sets the dot diameter. |
| `badgeLargeSize` | `largeSize` | `16` | Sets labeled-badge height and ordinary count-circle diameter. |
| `badgeTextStyle` | `textStyle` | Theme label-small style | Sets label typography. |
| `badgePadding` | `padding` | No circle padding; 4 horizontal for pills | Sets inner label spacing. |
| `badgeAlignment` | `alignment` | `AlignmentDirectional.topEnd` | Anchors the indicator to the launcher. |
| `badgeOffset` | `offset` | `Offset(1, -1)` | Moves the indicator after alignment. |

When a custom `builder` is passed to `WisperBotChat.launcher`, that builder owns
the entire launcher UI. The launcher's automatic badge decoration and its
`badge*` options are not applied to the builder output. The builder can render
`state.unreadCount` directly or wrap a shared-runtime child with
`WisperBotChat.badge`.

## How unread state behaves

| Event | Result |
|---|---|
| An unread, non-activity agent message arrives | Unread count increases and the indicator appears. |
| A visitor message or activity event arrives | It is not counted as an unread agent reply. |
| Shared prebuilt chat becomes visible | Unread agent messages are optimistically marked read and the indicator clears. |
| The read request completes | The existing backend read state is synchronized. |
| A stale refresh or realtime payload arrives | It cannot downgrade a locally read message and restore the badge. |
| App returns to the foreground | History is refreshed and realtime is restored so missed messages can be recovered. |
| `WisperBotChat.logout()` or `shutdown()` runs | Shared unread state resets to zero. |

The default `registerVisitorOnAppLaunch: true` lets the shared runtime establish
the visitor session needed for unread updates before chat is opened for the
first time. If it is set to `false`, registration waits until chat is opened or
the runtime is otherwise started.

## Advanced: render a completely custom indicator

Most applications should use `WisperBotChat.badge`. If the visual behavior is
entirely custom, listen to the shared `ValueListenable<int>`:

```dart
ValueListenableBuilder<int>(
  valueListenable: WisperBotChat.unreadCount,
  builder: (context, unreadCount, child) {
    return MyChatButton(
      hasUnreadMessages: unreadCount > 0,
      unreadCount: unreadCount,
      onPressed: () => WisperBotChat.open(context),
    );
  },
)
```

This lower-level API is optional; it is not necessary for ordinary custom
buttons.

## Advanced: explicit or headless controllers

`WisperBotChat.badge` listens to the shared runtime created by
`WisperBotChat.initialize`. Applications managing an explicit
`WisperBotChatController` should instead listen to `controller.states` and read:

- `state.unreadCount` for the number of unread agent messages.
- `state.hasUnreadMessages` for a boolean indicator.

Prebuilt chat surfaces mark messages read automatically when visible. A fully
custom chat UI must call:

```dart
await controller.markRead();
```

Call it when the conversation becomes visible to the user, not merely when an
incoming event is received.

## Troubleshooting

### The badge does not appear

- Confirm `WisperBotChat.initialize` completed successfully.
- Keep `registerVisitorOnAppLaunch: true` when replies must arrive before chat
  has ever opened, or explicitly start the runtime another way.
- Confirm the event is an unread agent message rather than a visitor message or
  activity event.
- For a custom launcher `builder`, render unread state yourself; automatic
  launcher decoration is intentionally bypassed.

### The badge does not clear

- Open a shared prebuilt WisperBot chat surface, or call `controller.markRead()`
  from a fully custom/headless chat when it becomes visible.
- Do not clear the visual locally without updating read state; a later refresh
  may correctly restore genuinely unread messages.

### The badge is in the wrong place

- Remember that alignment is relative to the wrapped child, not its parent.
- Adjust `offset` after choosing the correct alignment.
- Positive x moves right and negative y moves up.
- Check whether a parent widget clips content outside its bounds.

### The numeric badge is too wide

- Ordinary values from 1 through 99 are circles with the default maximum.
- Overflow values such as `99+` and custom labels intentionally use pills.
- Match `largeSize` to `textStyle`; 14–20 logical pixels is a practical range.
- Hot restart after changing SDK rendering code during local package
  development.
