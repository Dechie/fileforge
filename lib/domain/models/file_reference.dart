import 'dart:typed_data';

import 'package:fileforge/domain/enums/file_format.dart';

/// Platform-agnostic reference to a file.
///
/// Abstracts over Linux filesystem paths and Android content URIs
/// so the rest of the app never deals with the difference directly.
class FileReference {
  /// A display-friendly name (e.g. "report.pdf").
  final String displayName;

  /// The raw URI string (file path on Linux, content URI on Android).
  final String uri;

  /// MIME type if known.
  final String? mimeType;

  /// File size in bytes if known.
  final int? sizeBytes;

  /// Content-detected format (populated after inspection).
  final FileFormat? detectedFormat;

  /// Whether the app currently has read access to this file.
  final bool hasReadAccess;

  /// Whether the app currently has write access to this file.
  final bool hasWriteAccess;

  const FileReference({
    required this.displayName,
    required this.uri,
    this.mimeType,
    this.sizeBytes,
    this.detectedFormat,
    this.hasReadAccess = true,
    this.hasWriteAccess = false,
  });

  /// Create a copy with overridden fields.
  FileReference copyWith({
    String? displayName,
    String? uri,
    String? mimeType,
    int? sizeBytes,
    FileFormat? detectedFormat,
    bool? hasReadAccess,
    bool? hasWriteAccess,
  }) {
    return FileReference(
      displayName: displayName ?? this.displayName,
      uri: uri ?? this.uri,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      detectedFormat: detectedFormat ?? this.detectedFormat,
      hasReadAccess: hasReadAccess ?? this.hasReadAccess,
      hasWriteAccess: hasWriteAccess ?? this.hasWriteAccess,
    );
  }

  @override
  String toString() => 'FileReference($displayName, $uri)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileReference &&
          runtimeType == other.runtimeType &&
          uri == other.uri;

  @override
  int get hashCode => uri.hashCode;
}

/// Result of reading a file's magic bytes for format detection.
class FileSignature {
  final Uint8List bytes;
  final int length;

  const FileSignature(this.bytes, this.length);
}
