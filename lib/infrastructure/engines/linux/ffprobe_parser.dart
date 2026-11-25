import 'dart:convert';

import 'package:fileforge/domain/models/models.dart';

/// Turns `ffprobe -print_format json` output into [MediaMetadata].
class FfprobeParser {
  FfprobeParser._();

  static MediaMetadata parse(String jsonText) {
    final decoded = jsonDecode(jsonText);
    if (decoded is! Map) {
      throw const FormatException('ffprobe JSON was not an object');
    }
    final root = Map<String, dynamic>.from(decoded);
    final format = _map(root['format']);
    final streams = root['streams'];

    Map<String, dynamic>? video;
    Map<String, dynamic>? audio;
    final subtitleFormats = <String>[];
    final languages = <String>{};

    if (streams is List) {
      for (final entry in streams) {
        final stream = _map(entry);
        if (stream == null) continue;
        final type = stream['codec_type'];
        if (type == 'video' && video == null) {
          video = stream;
        } else if (type == 'audio' && audio == null) {
          audio = stream;
        } else if (type == 'subtitle') {
          final codec = stream['codec_name'];
          if (codec is String && codec.isNotEmpty) subtitleFormats.add(codec);
        }
        final language = _map(stream['tags'])?['language'];
        if (language is String && language.isNotEmpty) languages.add(language);
      }
    }

    final formatTags = _stringMap(_map(format?['tags']));
    for (final language in languages) {
      formatTags.putIfAbsent('language:$language', () => language);
    }

    return MediaMetadata(
      container: format?['format_name'] as String?,
      duration: _duration(format?['duration']),
      overallBitrate: _int(format?['bit_rate']),
      videoCodec: video?['codec_name'] as String?,
      width: _int(video?['width']),
      height: _int(video?['height']),
      frameRate: _rate(video?['avg_frame_rate'] ?? video?['r_frame_rate']),
      videoBitrate: _int(video?['bit_rate']),
      pixelFormat: video?['pix_fmt'] as String?,
      audioCodec: audio?['codec_name'] as String?,
      audioBitrate: _int(audio?['bit_rate']),
      audioChannels: _int(audio?['channels']),
      sampleRate: _int(audio?['sample_rate']),
      subtitleStreamCount: subtitleFormats.length,
      subtitleFormats: subtitleFormats,
      streamLanguages: languages.toList(),
      rawMetadata: formatTags,
    );
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static Map<String, String> _stringMap(Map<String, dynamic>? tags) {
    if (tags == null) return {};
    return tags.map((key, value) => MapEntry(key, '$value'));
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static Duration? _duration(Object? value) {
    final seconds = value is num ? value.toDouble() : double.tryParse('$value');
    if (seconds == null || seconds < 0 || value == null) return null;
    return Duration(microseconds: (seconds * 1000000).round());
  }

  static double? _rate(Object? value) {
    if (value == null) return null;
    final text = '$value';
    if (text.isEmpty || text == '0/0' || text == 'N/A') return null;
    if (text.contains('/')) {
      final parts = text.split('/');
      if (parts.length != 2) return null;
      final numerator = double.tryParse(parts[0]);
      final denominator = double.tryParse(parts[1]);
      if (numerator == null || denominator == null || denominator == 0) {
        return null;
      }
      return numerator / denominator;
    }
    return double.tryParse(text);
  }
}
