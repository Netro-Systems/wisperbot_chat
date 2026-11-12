# WisperBot Chat API

## Lookup images

The visitor API can include an optional `lookup_images` array on a bot reply.
Each entry has an HTTPS `image_url` and may have a `label` describing the image.
The SDK uses the same decoder for history, refreshes, and realtime messages.
It considers up to three entries and skips malformed entries and unsupported
URLs. If the field is absent or empty, the decoded message has an empty list.

Custom chat UIs receive the decoded list through `WisperBotMessage.lookupImages`.
Each `WisperBotLookupImage` provides a `Uri url` and a `String label`. The label
is empty when the backend does not provide one. Use `body` for reply text and
`lookupImages` for optional images to display above it.
