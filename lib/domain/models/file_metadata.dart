import 'package:fileforge/domain/enums/file_format.dart';

/// Generic metadata about any file.
class FileMetadata {
  final String? fileName;
  final int? sizeBytes;
  final String? mimeType;
  final FileFormat? format;
  final DateTime? created;
  final DateTime? modified;

  const FileMetadata({
    this.fileName,
    this.sizeBytes,
    this.mimeType,
    this.format,
    this.created,
    this.modified,
  });
}

/// Metadata specific to media files (video / audio).
class MediaMetadata {
  // Container / format
  final String? container;
  final Duration? duration;
  final int? overallBitrate;

  // Video stream
  final String? videoCodec;
  final int? width;
  final int? height;
  final double? frameRate;
  final int? videoBitrate;
  final String? pixelFormat;

  // Audio stream
  final String? audioCodec;
  final int? audioBitrate;
  final int? audioChannels;
  final int? sampleRate;

  // Streams
  final int subtitleStreamCount;
  final List<String> subtitleFormats;
  final List<String> streamLanguages;
  final Map<String, String> rawMetadata;

  const MediaMetadata({
    this.container,
    this.duration,
    this.overallBitrate,
    this.videoCodec,
    this.width,
    this.height,
    this.frameRate,
    this.videoBitrate,
    this.pixelFormat,
    this.audioCodec,
    this.audioBitrate,
    this.audioChannels,
    this.sampleRate,
    this.subtitleStreamCount = 0,
    this.subtitleFormats = const [],
    this.streamLanguages = const [],
    this.rawMetadata = const {},
  });
}

/// Metadata specific to image files.
class ImageMetadata {
  final int? width;
  final int? height;
  final String? colorProfile;
  final bool hasTransparency;
  final int? orientation;
  final bool isAnimated;
  final int? frameCount;
  final bool hasGpsData;
  final Map<String, String> exifData;

  const ImageMetadata({
    this.width,
    this.height,
    this.colorProfile,
    this.hasTransparency = false,
    this.orientation,
    this.isAnimated = false,
    this.frameCount,
    this.hasGpsData = false,
    this.exifData = const {},
  });
}

/// Metadata specific to PDF files.
class PdfMetadata {
  final int? pageCount;
  final double? pageWidth;
  final double? pageHeight;
  final bool isEncrypted;
  final String? title;
  final String? author;
  final String? subject;
  final String? creator;
  final DateTime? creationDate;
  final DateTime? modificationDate;
  final Map<String, String> properties;

  const PdfMetadata({
    this.pageCount,
    this.pageWidth,
    this.pageHeight,
    this.isEncrypted = false,
    this.title,
    this.author,
    this.subject,
    this.creator,
    this.creationDate,
    this.modificationDate,
    this.properties = const {},
  });
}
