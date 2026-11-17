# WisperBot Chat API

## Photo uploads

When the authenticated widget session advertises `config.photo_messages: true`,
the prebuilt gallery stages each selected image at `POST /widget/v1/photo-uploads`
and submits one ordered list to `POST /widget/v1/messages`. Custom composers
use `controller.stagePhoto` once per file with the shared UUID `requestId`
and a per-file UUID `uploadId`, then call `controller.sendPhotoMessage`
with that request ID, the returned attachment IDs in order, and the caption.
Keep the IDs and caption stable across retries. A committed message has one ID
and exposes its photos as `WisperBotMessage.attachments` in order.

The prebuilt chat and gallery automatically renew expired signed links for
committed photos. Custom renderers can call `controller.renewPhotoLink` with the
message ID and the attachment ID. This uses the active widget session and returns
a fresh `Uri` without fetching the conversation again.

`POST /widget/v1/messages` accepts one multipart `attachment` per request.
When the session lacks the grouped feature, the prebuilt composer sends a multi-photo selection in order with a shared
`photo_group_id` and puts its caption on the first photo.

Host apps with a custom composer can call `WisperBotChatController.sendImage`
once per photo with the same UUID in the optional `photoGroupId` argument.
Each photo has its own message and delivery status. Custom message renderers can
read the group from `WisperBotMessage.photoGroupId`.

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
