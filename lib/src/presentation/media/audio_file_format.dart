/// Uses the file signature before URL/filename hints. Native players can reject
/// valid audio when a downloaded file has the wrong extension.
String audioFileExtension(List<int> header,
    {required String filename, String? contentType}) {
  bool matches(List<int> signature, [int offset = 0]) {
    if (header.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (header[offset + i] != signature[i]) return false;
    }
    return true;
  }

  if (matches('ftyp'.codeUnits, 4)) return 'm4a';
  if (matches('ID3'.codeUnits)) return 'mp3';
  if (matches('RIFF'.codeUnits) && matches('WAVE'.codeUnits, 8)) return 'wav';
  if (matches('OggS'.codeUnits)) return 'ogg';
  if (matches([0x1a, 0x45, 0xdf, 0xa3])) return 'webm';
  if (matches('fLaC'.codeUnits)) return 'flac';
  if (matches('caff'.codeUnits)) return 'caf';
  if (matches('#!AMR'.codeUnits)) return 'amr';
  if (header.length >= 2 && header[0] == 0xff) {
    if ((header[1] & 0xf6) == 0xf0) return 'aac';
    if ((header[1] & 0xe0) == 0xe0 && (header[1] & 0x06) != 0) return 'mp3';
  }

  final mimeExtension =
      switch (contentType?.split(';').first.trim().toLowerCase()) {
    'audio/mp4' || 'audio/m4a' || 'audio/x-m4a' => 'm4a',
    'audio/mpeg' || 'audio/mp3' => 'mp3',
    'audio/aac' || 'audio/aacp' => 'aac',
    'audio/wav' || 'audio/x-wav' || 'audio/wave' => 'wav',
    'audio/ogg' || 'application/ogg' => 'ogg',
    'audio/webm' || 'video/webm' => 'webm',
    'audio/flac' || 'audio/x-flac' => 'flac',
    'audio/x-caf' => 'caf',
    'audio/amr' => 'amr',
    _ => null,
  };
  if (mimeExtension != null) return mimeExtension;
  final extension = filename.split('.').last.toLowerCase();
  return const {
    'm4a',
    'mp4',
    'mp3',
    'aac',
    'wav',
    'ogg',
    'oga',
    'opus',
    'webm',
    'weba',
    'amr',
    'flac',
    'caf',
  }.contains(extension)
      ? extension
      : 'audio';
}
