import 'package:fileforge/application/output_paths.dart';
import 'package:fileforge/domain/enums/enums.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saved names map back to the studio that wrote them', () {
    expect(
      studioForSavedName('notes_pdfMerge_171000.pdf'),
      StudioType.pdfStudio,
    );
    expect(
      studioForSavedName('chapter_markdownToPdf_171000.pdf'),
      StudioType.documentStudio,
    );
    expect(
      studioForSavedName('clip_videoTrim_171000.mp4'),
      StudioType.videoStudio,
    );
    expect(
      studioForSavedName('song_audioConvert_171000.mp3'),
      StudioType.audioStudio,
    );
    expect(studioForSavedName('clip_frames'), StudioType.videoStudio);
    expect(studioForSavedName('report_pages'), StudioType.pdfStudio);
  });

  test('document conversions are not filed under PDF', () {
    expect(
      studioForSavedName('notes_documentToPdf_171000.pdf'),
      StudioType.documentStudio,
    );
  });
}
