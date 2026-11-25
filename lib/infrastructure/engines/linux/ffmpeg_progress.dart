/// One parsed FFmpeg progress line.
class FfmpegProgressSnapshot {
  final double? fraction;
  final String? speed;
  final int? frame;

  const FfmpegProgressSnapshot({this.fraction, this.speed, this.frame});

  bool get isEmpty => fraction == null && speed == null && frame == null;
}

/// Parses FFmpeg `-progress` lines and the classic `time=` stats line.
class FfmpegProgress {
  FfmpegProgress._();

  // `out_time` is listed before `time` so `out_time=` is not read as `time=`.
  static final _time = RegExp(
    r'(?:^|\s)(?:out_time|time)=(\d+):(\d+):(\d+(?:\.\d+)?)',
  );
  static final _speed = RegExp(r'speed=\s*([0-9.]+)x');
  static final _frame = RegExp(r'(?:^|\s)frame=\s*(\d+)');

  static FfmpegProgressSnapshot parse(String line, {Duration? total}) {
    double? fraction;
    final timeMatch = _time.firstMatch(line);
    if (timeMatch != null && total != null && total.inMicroseconds > 0) {
      final hours = int.parse(timeMatch.group(1)!);
      final minutes = int.parse(timeMatch.group(2)!);
      final seconds = double.parse(timeMatch.group(3)!);
      final micros =
          ((hours * 3600 + minutes * 60 + seconds) * 1000000).round();
      fraction = (micros / total.inMicroseconds).clamp(0.0, 1.0);
    }

    return FfmpegProgressSnapshot(
      fraction: fraction,
      speed: _speed.firstMatch(line)?.group(1),
      frame: int.tryParse(_frame.firstMatch(line)?.group(1) ?? ''),
    );
  }
}
