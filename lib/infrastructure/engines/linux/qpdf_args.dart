import 'package:fileforge/core/errors/app_exceptions.dart';

/// Argument lists for the qpdf 12 CLI. Each value is one argv element.
class QpdfArgs {
  QpdfArgs._();

  static List<String> merge(List<String> inputs, String outputPath) {
    if (inputs.length < 2) {
      throw const FileValidationException('Merge needs at least two PDF files');
    }
    return ['--empty', '--pages', ...inputs, '--', outputPath];
  }

  static List<String> selectPages(
    String inputPath,
    String pageList,
    String outputPath,
  ) {
    return [inputPath, '--pages', inputPath, pageList, '--', outputPath];
  }

  static List<String> rotate(
    String inputPath,
    String outputPath,
    List<String> flags,
  ) {
    return [inputPath, outputPath, ...flags];
  }

  static List<String> split(String inputPath, String patternPath) {
    return ['--split-pages', inputPath, patternPath];
  }

  static List<String> compress(String inputPath, String outputPath) {
    return [
      '--object-streams=generate',
      '--recompress-flate',
      '--compression-level=9',
      '--optimize-images',
      inputPath,
      outputPath,
    ];
  }

  static List<String> overlay({
    required String inputPath,
    required String stampPath,
    required String outputPath,
    bool repeatFirstPage = false,
  }) {
    return [
      inputPath,
      '--overlay',
      stampPath,
      if (repeatFirstPage) '--repeat=1',
      '--',
      outputPath,
    ];
  }

  static List<String> encrypt(
    String inputPath,
    String outputPath,
    String password,
  ) {
    if (password.isEmpty) {
      throw const FileValidationException('Password cannot be empty');
    }
    return [
      '--encrypt',
      '--user-password=$password',
      '--owner-password=$password',
      '--bits=256',
      '--',
      inputPath,
      outputPath,
    ];
  }

  static List<String> decrypt(
    String inputPath,
    String outputPath,
    String password,
  ) {
    if (password.isEmpty) {
      throw const FileValidationException('Password cannot be empty');
    }
    return ['--password=$password', '--decrypt', inputPath, outputPath];
  }

  static List<String> inspect(String inputPath) {
    return ['--json', '--json-stream-data=none', inputPath];
  }

  static List<String> showPageCount(String inputPath) {
    return ['--show-npages', inputPath];
  }

  /// Keep the caller's page order. Page numbers are 1-based.
  static String pageList(List<int> pages) {
    if (pages.isEmpty) {
      throw const FileValidationException('No pages selected');
    }
    for (final page in pages) {
      if (page < 1) {
        throw const FileValidationException('Page numbers start at 1');
      }
    }
    return pages.join(',');
  }

  /// Pages that remain after [deleted] is removed, as a qpdf range.
  static String complementPages(int pageCount, List<int> deleted) {
    if (pageCount < 1) {
      throw const FileValidationException('PDF has no pages');
    }
    final drop = deleted.toSet();
    for (final page in drop) {
      if (page < 1 || page > pageCount) {
        throw FileValidationException('Page $page is outside 1-$pageCount');
      }
    }
    final keep = <int>[
      for (var i = 1; i <= pageCount; i++)
        if (!drop.contains(i)) i,
    ];
    if (keep.isEmpty) {
      throw const FileValidationException('Refusing to delete every page');
    }
    return _ranges(keep);
  }

  static List<String> rotateFlags(Map<int, int> rotations) {
    final grouped = <int, List<int>>{};
    rotations.forEach((page, angle) {
      if (page < 1) {
        throw const FileValidationException('Page numbers start at 1');
      }
      final normalized = _normalizeAngle(angle);
      if (normalized != 0 &&
          normalized != 90 &&
          normalized != 180 &&
          normalized != 270) {
        throw const FileValidationException(
          'Rotation must be a multiple of 90 degrees',
        );
      }
      if (normalized == 0) return;
      grouped.putIfAbsent(normalized, () => []).add(page);
    });
    if (grouped.isEmpty) {
      throw const FileValidationException('No rotations requested');
    }
    final angles = grouped.keys.toList()..sort();
    return [
      for (final angle in angles)
        '--rotate=$angle:${(grouped[angle]!..sort()).join(',')}',
    ];
  }

  static int _normalizeAngle(int angle) {
    final mod = angle % 360;
    return mod < 0 ? mod + 360 : mod;
  }

  static String _ranges(List<int> sortedPages) {
    final parts = <String>[];
    var start = sortedPages.first;
    var previous = start;
    for (final page in sortedPages.skip(1)) {
      if (page == previous + 1) {
        previous = page;
        continue;
      }
      parts.add(start == previous ? '$start' : '$start-$previous');
      start = previous = page;
    }
    parts.add(start == previous ? '$start' : '$start-$previous');
    return parts.join(',');
  }
}

/// Remove a password from text that might be shown to the user.
String redactSecret(String text, String secret) {
  if (secret.isEmpty) return text;
  return text.replaceAll(secret, '***');
}
