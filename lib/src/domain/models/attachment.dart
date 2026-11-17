part of 'models.dart';

/// Attachment metadata returned with a message.
class WisperBotAttachment {
  /// Creates attachment metadata.
  const WisperBotAttachment({
    required this.url,
    this.filename,
    this.mimeType,
    this.id,
    this.sizeBytes,
  });

  /// Server attachment URL.
  final Uri url;

  /// Original filename when supplied by the backend.
  final String? filename;

  /// MIME type when supplied by the backend.
  final String? mimeType;

  /// Server photo ID when the attachment was staged for a grouped message.
  final String? id;

  /// File size reported by the server, in bytes.
  final int? sizeBytes;
}

/// In-memory media selected by the host for upload.
class WisperBotUpload {
  /// Creates an upload and defensively copies [bytes].
  WisperBotUpload({
    required Uint8List bytes,
    required this.filename,
    required this.mimeType,
  }) : bytes = Uint8List.fromList(bytes);

  /// Immutable-by-convention upload bytes owned by this value.
  final Uint8List bytes;

  /// Original filename sent in multipart data.
  final String filename;

  /// Host-reported MIME type used for local validation.
  final String mimeType;
}
