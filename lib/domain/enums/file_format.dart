/// Categories of file formats the app understands.
enum FileCategory { video, audio, image, pdf, document, subtitle, unknown }

/// Known file formats and their metadata.
enum FileFormat {
  // Video containers
  mp4(FileCategory.video, 'MP4', ['mp4', 'm4v'], ['video/mp4']),
  mkv(FileCategory.video, 'MKV', ['mkv'], ['video/x-matroska']),
  webm(FileCategory.video, 'WebM', ['webm'], ['video/webm']),
  mov(FileCategory.video, 'MOV', ['mov'], ['video/quicktime']),

  // Audio
  mp3(FileCategory.audio, 'MP3', ['mp3'], ['audio/mpeg']),
  wav(FileCategory.audio, 'WAV', ['wav'], ['audio/wav', 'audio/x-wav']),
  flac(FileCategory.audio, 'FLAC', ['flac'], ['audio/flac']),
  aac(FileCategory.audio, 'AAC', ['aac'], ['audio/aac']),
  m4a(FileCategory.audio, 'M4A', ['m4a'], ['audio/mp4', 'audio/x-m4a']),
  ogg(FileCategory.audio, 'OGG', ['ogg'], ['audio/ogg']),
  opus(FileCategory.audio, 'Opus', ['opus'], ['audio/opus']),

  // Images
  jpg(FileCategory.image, 'JPEG', ['jpg', 'jpeg'], ['image/jpeg']),
  png(FileCategory.image, 'PNG', ['png'], ['image/png']),
  webpImage(FileCategory.image, 'WebP', ['webp'], ['image/webp']),
  heic(
    FileCategory.image,
    'HEIC',
    ['heic', 'heif'],
    ['image/heic', 'image/heif'],
  ),

  // PDF
  pdf(FileCategory.pdf, 'PDF', ['pdf'], ['application/pdf']),

  // Documents
  docx(
    FileCategory.document,
    'DOCX',
    ['docx'],
    ['application/vnd.openxmlformats-officedocument.wordprocessingml.document'],
  ),
  pptx(
    FileCategory.document,
    'PPTX',
    ['pptx'],
    [
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    ],
  ),
  xlsx(
    FileCategory.document,
    'XLSX',
    ['xlsx'],
    ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'],
  ),
  odt(
    FileCategory.document,
    'ODT',
    ['odt'],
    ['application/vnd.oasis.opendocument.text'],
  ),
  ods(
    FileCategory.document,
    'ODS',
    ['ods'],
    ['application/vnd.oasis.opendocument.spreadsheet'],
  ),
  odp(
    FileCategory.document,
    'ODP',
    ['odp'],
    ['application/vnd.oasis.opendocument.presentation'],
  ),
  markdown(
    FileCategory.document,
    'Markdown',
    ['md', 'markdown'],
    ['text/markdown'],
  ),

  // Subtitles
  srt(FileCategory.subtitle, 'SRT', ['srt'], ['application/x-subrip']),
  ass(
    FileCategory.subtitle,
    'ASS/SSA',
    ['ass', 'ssa'],
    ['text/x-ssa', 'text/x-ass'],
  );

  final FileCategory category;
  final String displayName;
  final List<String> extensions;
  final List<String> mimeTypes;

  const FileFormat(
    this.category,
    this.displayName,
    this.extensions,
    this.mimeTypes,
  );

  /// Attempt to identify a format by file extension (secondary hint only).
  static FileFormat? fromExtension(String ext) {
    final lower = ext.toLowerCase().replaceFirst('.', '');
    for (final format in values) {
      if (format.extensions.contains(lower)) return format;
    }
    return null;
  }

  /// Attempt to identify a format by MIME type.
  static FileFormat? fromMimeType(String mime) {
    final lower = mime.toLowerCase();
    for (final format in values) {
      if (format.mimeTypes.contains(lower)) return format;
    }
    return null;
  }
}
