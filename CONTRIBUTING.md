# Contributing to WisperBot Chat

## Architecture

Dependencies flow toward the domain:

```text
presentation -> application -> domain <- data
configuration --------^          ^
             application runtime wires adapters
```

- `configuration` owns public host options, including Flutter presentation
  values.
- `domain` owns immutable chat concepts, typed failures, events, and contracts.
- `application` owns session orchestration, state, polling, sending, lifecycle,
  and reconciliation.
- `data` owns HTTP, JSON mapping, secure storage, and other external systems.
- `presentation` renders controller state and never performs HTTP directly.
- `application/wisperbot_runtime.dart` is the private composition point that
  wires data adapters without widening the public API.

Put a declaration in the narrowest layer that owns its rules. Do not create
generic `core`, `common`, `helpers`, or `utils` dumping grounds.

## Public API

Only exports from `lib/wisperbot_chat.dart` are supported public API. Adding an
export, required parameter, enum value with behavioral impact, or changing a
default requires an API review and documentation update. Consumers and the
example must import the public barrel; tests may deep-import `src` only to test
an internal boundary directly.

Public declarations require Dartdoc that explains observable behavior,
defaults, lifecycle/ownership, typed failures, and security constraints where
relevant. Internal comments explain why an invariant exists; they should not
repeat what a statement already says.

## Files and naming

- Prefer one primary responsibility per file.
- Keep wire DTOs and JSON maps inside `data`.
- Keep Flutter widgets and colors outside `domain`.
- Name coordinators after the behavior they own.
- Keep injectable boundaries around network, storage, lifecycle, and media.
- Avoid singleton state; dependencies are passed through constructors.

## Tests

The test tree mirrors `lib/src`. Place reusable doubles and deterministic data
in `test/support/fakes`, `test/support/fixtures`, and `test/support/builders`.
Use fake HTTP clients and in-memory or platform-mocked storage; automated tests
must not contact production.

Golden files protect the current prebuilt UI. Generate them with fixed viewport,
pixel ratio, fonts, time, data, and animation settings. Update a golden only for
an approved visual change, describe that change in the review, and inspect the
new image before committing it. Moving a widget to another file is not a reason
to regenerate a golden.

## Reliability and security

- The encrypted visitor token authorizes history; a conversation ID does not.
- Scope stored sessions by canonical API origin, widget key, and identity.
- Never log tokens, signatures, identities, message bodies, or attachment URLs.
- Never fabricate browser `Origin` or `Referer` headers for native clients.
- Only session and poll batches advance the receive cursor.
- Never automatically retry an ambiguous send without backend idempotency.
- Polls must not overlap and must stop without listeners or in background.

## Required checks

Run before submitting a change:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
dart doc
cd example
flutter analyze
flutter test
flutter build apk
```

Update `docs/ARCHITECTURE.md` when boundaries change and `docs/API.md` when an
intentional public or backend contract changes.
