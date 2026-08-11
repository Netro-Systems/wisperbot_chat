# WisperBot Flutter SDK Design System

## Goal

Deliver a calm, trustworthy chat experience that is production-ready by default while adapting to the host app and the branding configured in WisperBot.

The design works in full-screen, floating-launcher, embedded, modal/bottom-sheet, and custom/headless integrations.

## Principles

### Conversation first

Messages and composer are the focus. Branding, status, and actions support the conversation without dominating it.

### Familiar interaction

Use established messaging patterns: inbound/outbound alignment, clear send state, predictable composer behavior, visible attachments, and careful auto-scroll.

### Honest status

Clearly distinguish connecting, reconnecting, sending, definitively failed,
delivery unconfirmed, network offline, support unavailable, bot, and human-agent
states.

### Brand-safe defaults

Server configuration supplies brand color, title, subtitle, agent name, logo, and team. Local overrides may adjust presentation but must preserve readable contrast.

### Accessible by default

Controls require semantics, sufficient touch targets, focus behavior, scalable text, contrast, and reduced-motion support.

## Theme resolution

Resolve appearance in this order:

1. Explicit host `WisperBotThemeData`
2. WisperBot server widget colors when `WisperBotConfig.useApiColors` is `true`
3. Built-in WisperBot palette (`#FF762E`, white surfaces, `#F7F8FA` canvas)
4. Host `ThemeData`/`ColorScheme` for brightness, typography, errors, and any
   remaining roles

Host overrides affect appearance only, never identity or server behavior.
Setting `useApiColors` to `false` does not disable custom colors; it only removes
the server palette from resolution. A custom primary, bubble, background, or
surface color continues to override the built-in palette.

## Public theme model

```dart
class WisperBotThemeData {
  const WisperBotThemeData({
    this.primaryColor,
    this.backgroundColor,
    this.surfaceColor,
    this.visitorBubbleColor,
    this.agentBubbleColor,
    this.onVisitorBubbleColor,
    this.onAgentBubbleColor,
    this.errorColor,
    this.borderRadius,
    this.messageSpacing,
    this.launcherSize,
    this.brightness,
  });

  final Color? primaryColor;
  final Color? backgroundColor;
  final Color? surfaceColor;
  final Color? visitorBubbleColor;
  final Color? agentBubbleColor;
  final Color? onVisitorBubbleColor;
  final Color? onAgentBubbleColor;
  final Color? errorColor;
  final double? borderRadius;
  final double? messageSpacing;
  final double? launcherSize;
  final Brightness? brightness;
}
```

An internal `ThemeExtension` is acceptable, but the public API remains simple.

## Color roles

| Token | Purpose |
|---|---|
| `primary` | Launcher, visitor bubble, focused controls, primary action |
| `onPrimary` | Text/icons on primary |
| `surface` | Header, composer, cards |
| `surfaceMuted` | Agent bubble and secondary areas |
| `background` | Timeline |
| `onSurface` | Main text |
| `onSurfaceMuted` | Timestamp/status text |
| `outline` | Dividers and borders |
| `error` | Failed messages and errors |
| `success` | Connected/online confirmation when useful |

Requirements:

- Meet WCAG AA contrast for normal text.
- Calculate foreground contrast; never assume white works on the server color.
- Never use color as the only status signal.
- Resolve dark surfaces independently rather than simply inverting colors.

## Typography

Use the host text theme by default.

| Role | Default intent |
|---|---|
| Header title | `titleMedium`, semibold |
| Header subtitle/status | `bodySmall` |
| Message body | `bodyMedium` |
| Message metadata | `labelSmall` |
| Composer text | `bodyMedium` |
| Action label | `labelLarge` |

- Support system scaling without clipping.
- Do not hardcode a font family.
- Make message text selectable where practical.
- Respect right-to-left directionality.

## Spacing and shape

Use a 4-point grid: 4, 8, 12, 16, 20, 24, and 32 logical pixels.

Defaults:

- Bubble radius: 16
- Composer radius: 20
- Card/sheet radius: 20
- Launcher: circular, 56 logical pixels
- Minimum target: 48 logical pixels
- Bubble width: at most 76% on phones and capped for readability on larger surfaces

## Presentation behavior

### Full-screen screen

- Uses `SafeArea` correctly.
- Header has appropriate back/close behavior.
- Timeline fills remaining space.
- Composer stays above the keyboard.
- Host may provide header actions.

### Floating launcher

- Default size 56.
- Bottom-right and bottom-left positioning.
- Supports safe-area and custom insets.
- The built-in launcher remains absent and non-interactive until API widget
  configuration has loaded, then zooms around its fixed center from 0% to 100%
  size over 240ms without changing position. It appears immediately when
  reduced motion is enabled.
- Uses the server launcher logo when available and the package-owned WisperBot
  logo as the loading, missing-logo, and remote-image-error fallback.
- Sizes the launcher logo to four-sevenths of the configured launcher diameter.
- One tap cannot open duplicate chat routes.

### Embedded view

- Makes no `Scaffold` or navigation assumptions.
- Uses actual layout constraints, not global screen width.
- Header can be shown or hidden.
- Does not alter system overlays.
- Supports nested keyboard layouts.

### Modal/bottom sheet

- Phone defaults to full screen for keyboard reliability.
- Bottom sheets use 96% of the available safe height by default and remain
  scroll-controlled for keyboard use.
- Tablet/desktop may use a constrained dialog or side panel.
- Host may choose presentation explicitly.

## Components

### Chat header

Displays widget logo/fallback, title, subtitle/live status, an AI/human indicator when accurate, and close/back action.

The default branded header uses the server primary color with a contrast-safe
foreground, server avatar, package-owned WisperBot logo fallback, availability
dot, and configured subtitle, matching the WisperBot web widget while remaining
theme-overridable.

Do not imply a named human is assigned merely because generic `agent_name` exists.

### Welcome state

Server welcome text is introductory UI, not a persisted message unless returned
as one. The default UI keeps it as a leading inbound-style welcome bubble above
the timeline, matching the web widget without inserting it into controller
state, events, or persistence.

### Pre-chat

When the server requires pre-chat, collect only the configured fields, explain
why they are requested, validate them accessibly, and never imply marketing
consent. Do not render the composer until the required fields have been accepted
by the backend. The first session response supplies the configuration.
Submission repeats that session with the returned visitor ID/token and the
collected name/email, then uses the refreshed configuration and history.

### Timeline

- Visitor messages align trailing; agent/bot messages leading.
- Group consecutive messages from the same role.
- Show timestamps with low emphasis.
- Preserve scroll position when older messages prepend.
- Auto-scroll only when near the bottom or after the visitor sends.
- Show a new-message affordance when scrolled away.

### Bubble states

Visitor states:

- `pending`: tracked internally while the request is in flight
- `sent`: tracked internally after server confirmation
- `failed`: definitive rejection plus retry/remove action when retry is safe
- `unconfirmed`: the request outcome is unknown; refresh first and warn that
  resending before backend idempotency may create a duplicate

The default bubble does not display routine `Sending` or `Sent` labels. The
backend may perform synchronous post-persistence work before returning, and a
routine label would make that server latency look like a client-side delay.
Failed and delivery-unconfirmed states remain visible and actionable.

Agent messages may show a backend-supplied sender. Do not guess AI versus human when `sent_by` is absent.

### Rich messages

Initial types:

- Image with loading, error, preview, and inspect action
- Audio with play/pause, optional duration, and accessible label
- Agent file with filename/open action when supported

Never execute HTML from messages. Render text safely and require explicit action to open links.

### Composer

Includes multiline input, optional attachment/voice actions, and send. The
default attachment and voice controls appear when the host supplies a
`WisperBotMediaAdapter`; the current backend supports both media routes.

- Empty text cannot send.
- Preserve the draft for the active controller/identity scope. Drafts are
  memory-only unless an explicit encrypted cache adapter supports them.
- Clear the visible draft before switching identity or logging out.
- Provide an explicit send button.
- Disable only unavailable actions; polling must not freeze the composer.
- Announce validation/upload errors accessibly.
- Preview a selected image before upload. While recording, show a live status
  and provide an explicit cancel. Stopping creates an audio confirmation with
  explicit Send and Discard actions so recording never implies delivery.

### Typing indicator

Use subtle dots plus “Support is typing”. Respect reduced motion with a static indicator and remove stale state promptly.

### Handoff action

States:

- Hidden/unavailable
- Eligible: “Talk to a person”
- Requesting
- Connected: “Connected to support”
- Failed with retry

Do not promise immediate availability unless the backend guarantees it.

### Connection state

- Initial session loading: show only neutral shimmer placeholders for the
  header, its lower divider, conversation, and composer geometry. Keep the
  composer clear of the system gesture area with generous bottom spacing. Do
  not reveal fallback branding, text, icons, logos, message content, or brand
  colors before configuration has loaded. Keep an accessible live-region label,
  and hold the placeholders static when reduced motion is enabled.
- Reconnecting: compact persistent banner
- Network offline: explain that messages cannot currently be confirmed
- Configuration/authorization failure: actionable full-state error

### Support availability

Working-hours availability is independent of network connection. When support
is unavailable, show the server's offline message or a neutral fallback and set
expectations for a later reply. Do not disable sending solely because support is
outside working hours unless the server explicitly forbids it.

## Responsive layout

Suggested behavior:

- `<600dp`: phone full-width/full-screen
- `600–1023dp`: tablet, optionally constrained panel
- `>=1024dp`: desktop/web capped width or side panel

Embedded mode always uses local constraints.

## Motion

- Launcher transition: 180–240ms
- New message: subtle fade/size transition
- Avoid animating the entire timeline
- Respect `MediaQuery.disableAnimations`
- Never delay functional state until animation completes

## Accessibility

- 48x48 minimum targets
- Semantic labels for launcher, close, send, attach, media, retry, and handoff
- Announce new messages without rereading the whole timeline
- Maintain logical focus after modal transitions
- Visible keyboard focus on web/desktop
- Support screen readers and switch navigation
- Do not convey sender/delivery state only through alignment or color
- Test 200% text scale

## Localization

All SDK-owned strings are localizable. Server-owned title, welcome, and offline text render as received.

String groups include composer labels, delivery/error states, connection, typing, handoff, attachment actions, date/time grouping, and accessibility announcements.

Ship English fallback and let hosts override localization delegates or labels without forking components.

## Privacy

- Do not show OS notification message previews unless explicitly enabled.
- Keep message history in memory by default. Persistent body caching requires an
  explicit encrypted cache adapter and host opt-in.
- Clear drafts/cache/session on explicit reset.
- Never display raw external IDs, tokens, provider IDs, or internal conversation IDs.
- Support a host callback for its privacy policy.

## Visual QA checklist

Test:

- Light/dark themes
- Long title/name and long unbroken message/URL
- Empty, loading, offline, reconnecting, failed, and ready states
- Definitively failed and delivery-unconfirmed outgoing messages
- Required pre-chat and unsupported-required-field states
- Network offline versus support outside working hours
- AI, handoff eligible, and human-connected modes
- Keyboard open
- Right-to-left
- 200% text scale
- Small phone, tablet, and constrained desktop panel
- Image/audio loading and failure
