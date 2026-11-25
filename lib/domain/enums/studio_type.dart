/// Which studio/module an operation belongs to.
enum StudioType {
  pdfStudio('PDF Studio'),
  documentStudio('Document Studio'),
  imageStudio('Image Studio'),
  videoStudio('Video Studio'),
  audioStudio('Audio Studio'),
  storageManager('Storage Manager'),
  fileInspector('File Inspector'),
  engineManager('Engine Manager'),
  dependencyManager('Dependency Manager'),
  processingManager('Processing Manager');

  final String displayName;
  const StudioType(this.displayName);
}
