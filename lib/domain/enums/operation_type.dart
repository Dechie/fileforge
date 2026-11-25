/// Supported processing operations across all studios.
enum OperationType {
  // PDF operations
  pdfMerge('Merge PDFs'),
  pdfSplit('Split PDF'),
  pdfExtractPages('Extract Pages'),
  pdfReorderPages('Reorder Pages'),
  pdfRotatePages('Rotate Pages'),
  pdfDeletePages('Delete Pages'),
  pdfCompress('Compress PDF'),
  pdfAddWatermark('Add Watermark'),
  pdfAddPageNumbers('Add Page Numbers'),
  pdfProtect('Protect PDF'),
  pdfUnprotect('Remove Protection'),
  pdfInspect('Inspect PDF'),

  // Document operations
  documentToPdf('Convert to PDF'),
  markdownToPdf('Markdown to PDF'),

  // Image operations
  imageConvert('Convert Image'),
  imageResize('Resize Image'),
  imageCompress('Compress Image'),
  imageBatchConvert('Batch Convert'),
  imageBatchResize('Batch Resize'),
  imageInspect('Inspect Image'),
  imageRemoveMetadata('Remove Metadata'),

  // Video operations
  videoTrim('Trim Video'),
  videoCrop('Crop Video'),
  videoResize('Resize Video'),
  videoCompress('Compress Video'),
  videoConvertContainer('Convert Container'),
  videoConvertCodec('Convert Codec'),
  videoExtractAudio('Extract Audio'),
  videoRemoveAudio('Remove Audio'),
  videoExtractFrames('Extract Frames'),
  videoAddSubtitles('Add Subtitles'),
  videoExtractSubtitles('Extract Subtitles'),
  videoBurnSubtitles('Burn Subtitles'),
  videoAddCredits('Add Credits'),
  videoInspect('Inspect Video'),

  // Audio operations
  audioConvert('Convert Audio'),
  audioCompress('Compress Audio'),
  audioTrim('Trim Audio'),
  audioExtractFromVideo('Extract from Video'),
  audioInspect('Inspect Audio');

  final String displayName;
  const OperationType(this.displayName);
}
