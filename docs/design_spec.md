# Universal Utility
## Technical Design Specification

**Document version:** 0.1  
**Status:** Initial architecture and requirements specification  
**Target platforms:** Linux and Android  
**Application framework:** Flutter / Dart  
**Primary architectural approach:** Modular application with platform-specific processing engines  
**State management:** Provider  
**Processing philosophy:** Local-first, with optional future server-side capabilities

---

# 1. Product Overview

## 1.1 Purpose

Universal Utility is a cross-platform application that provides a collection of file manipulation, conversion, optimization, and media-processing tools through a unified interface.

The application is intended to consolidate functionality that would otherwise require installing several independent applications.

It will support:

- PDF manipulation.
- Office document conversion.
- Image conversion and optimization.
- Video editing and compression.
- Audio conversion and manipulation.
- General file-format conversion.
- File inspection and metadata management.
- Processing job management and storage management.

The application must remain modular. Each major functional area should be independently usable, and missing dependencies or processing engines should not unnecessarily prevent other modules from operating.

## 1.2 Core product principles

1. **Local-first processing:** Files should be processed locally whenever possible.
2. **Modular functionality:** Each studio should have clearly defined responsibilities and dependencies.
3. **Optional engines:** Specialized processing engines should be replaceable or independently installable.
4. **Minimal base installation:** Avoid bundling every processing library and codec into the initial application.
5. **Cross-platform consistency:** Maintain shared Dart interfaces and behavior while allowing platform-specific implementations.
6. **Data integrity:** Never overwrite original files unless the user explicitly requests it.
7. **Resource awareness:** Processing must account for CPU, memory, storage, and battery limitations.
8. **Transparent processing:** Users should understand what operations are being performed and whether they require transcoding, re-encoding, or metadata modification.
9. **Recoverability:** Persist processing-job information and support safe recovery where technically possible.
10. **Extensibility:** New formats, engines, and processing capabilities should be addable without restructuring the entire application.

---

# 2. Application Structure

## 2.1 Main application

The application will consist of a shared Flutter core and independently organized functional modules.

The initial studios are:

1. PDF Studio
2. Document Studio
3. Image Studio
4. Video Studio
5. Audio Studio
6. Storage Manager
7. File Inspector
8. Engine Manager
9. Dependency Manager
10. Processing Manager

Format conversion should initially be treated as a shared capability rather than an entirely separate processing engine.

## 2.2 Module responsibilities

### PDF Studio

Operations:

- Merge PDF files.
- Split PDFs.
- Extract selected pages.
- Reorder pages.
- Rotate pages.
- Delete pages.
- Compress PDFs.
- Add watermarks.
- Add page numbers.
- Protect documents with passwords.
- Remove passwords where the user has the necessary authorization and credentials.
- Inspect document properties.
- Generate page previews.

Advanced operations such as form editing, OCR, and digital-signature manipulation are outside the initial MVP scope.

### Document Studio

Supported document formats should initially include:

- DOCX
- PPTX
- XLSX
- ODT
- ODS
- ODP
- Markdown

Initial conversions:

- Office documents to PDF on Linux.
- Markdown to PDF.
- Supported document formats to PDF where a compatible local engine exists.

Linux will use LibreOffice in headless mode.

**Android Office conversion is explicitly unavailable in the MVP.**

A future version may introduce an opt-in server-side conversion service. That future implementation must separately address authentication, file uploads, encryption in transit, retention policies, privacy, operational cost, and failure handling.

The initial Android application must not silently upload documents for conversion.

### Image Studio

Initial formats:

- JPG/JPEG
- PNG
- WebP
- HEIC/HEIF

Operations:

- Convert image formats.
- Resize images.
- Compress images.
- Batch conversion.
- Batch resizing.
- Inspect image properties.
- Preserve or remove metadata.
- Handle transparency.
- Handle orientation.
- Preserve color profiles where possible.

Image-processing requirements:

- Respect EXIF orientation.
- Preserve alpha channels when the target format supports transparency.
- Preserve ICC color profiles where appropriate.
- Allow deliberate metadata removal.
- Treat GPS metadata as sensitive information.
- Detect animated images and avoid silently converting them into a single static frame.

### Video Studio

Initial functionality:

- Trim video.
- Crop video.
- Resize video.
- Compress video.
- Convert containers.
- Convert codecs where supported.
- Extract audio.
- Remove audio.
- Extract frames.
- Add subtitle tracks.
- Extract subtitle tracks.
- Burn subtitles into video.
- Add credits and styled text.
- Inspect streams and metadata.

Video editing must distinguish between operations that modify the encoded streams and operations that only change container organization.

### Audio Studio

Initial functionality:

- Convert audio formats.
- Compress audio.
- Trim audio.
- Extract audio from video.
- Remove or replace audio where supported.
- Inspect audio streams and metadata.

Initial formats:

- MP3
- WAV
- FLAC
- AAC
- M4A
- OGG
- Opus

### Storage Manager

The Storage Manager is a dedicated application module, not merely an internal utility.

Its responsibilities include:

- Monitoring available storage.
- Estimating required processing space.
- Managing temporary files.
- Managing intermediate files.
- Managing output files.
- Tracking file sizes.
- Cleaning abandoned processing artifacts.
- Managing application cache.
- Preventing accidental deletion of user originals.
- Providing storage usage information.
- Warning users when an operation may exceed available storage.
- Managing partial outputs and recoverable processing data.

The Storage Manager must understand the difference between:

- Original files.
- Temporary working copies.
- Intermediate processing artifacts.
- Partial outputs.
- Completed outputs.
- Cached previews.
- Recoverable checkpoints.

It must never automatically delete a file that is still referenced by an active or recoverable processing job.

---

# 3. Cross-Platform Architecture

## 3.1 General architecture

The application will use a layered architecture.

### Presentation layer

Responsible for:

- Flutter UI.
- Navigation.
- User interaction.
- Forms and settings.
- Progress presentation.
- Error presentation.
- Module availability indicators.

### Application layer

Responsible for:

- Use cases.
- Module orchestration.
- Processing workflows.
- Validation.
- Job creation.
- Engine selection.
- Dependency checks.
- Storage coordination.

### Domain layer

Contains shared models and contracts:

- FileReference
- FileMetadata
- MediaMetadata
- ProcessingJob
- ProcessingRequest
- ProcessingResult
- EngineCapability
- EngineDescriptor
- DependencyDescriptor
- ProcessingCheckpoint
- OutputArtifact

### Infrastructure layer

Responsible for:

- Platform-specific engine adapters.
- SQLite persistence.
- Filesystem integration.
- Native Android integration.
- Linux process execution.
- Temporary file handling.

## 3.2 State management

Use Provider for application state management.

Providers should be organized around functional responsibilities rather than one global state object.

Suggested providers:

- SystemProvider
- DependencyProvider
- EngineProvider
- StorageProvider
- ProcessingProvider
- JobHistoryProvider
- SettingsProvider
- FileSelectionProvider

Long-running processing must not block Flutter's main isolate.

State updates should be exposed through well-defined application services and providers.

## 3.3 Shared interfaces and platform adapters

All major processing operations should be accessed through shared Dart interfaces.

For example:

- PdfEngine
- VideoEngine
- AudioEngine
- ImageEngine
- DocumentEngine

Implementations will differ by platform.

The application should not contain platform-specific processing commands throughout its UI or business logic.

Instead, the UI requests an operation from the appropriate service, and the service selects a compatible engine.

This provides the ability to replace an engine without rewriting the associated module.

---

# 4. File Abstraction and Identification

## 4.1 FileReference

The application must not assume every file is represented by an ordinary filesystem path.

Linux generally uses filesystem paths, while Android may return content URIs through the Storage Access Framework.

A shared FileReference abstraction should support:

- Display name.
- MIME type, when available.
- File size, when available.
- URI or path representation.
- Read access.
- Stream access.
- Copying into a working directory.
- Exporting to a destination.
- Permission and access validation.

Android URI permissions must be managed correctly, including persisted permissions where applicable.

## 4.2 Content-based format detection

File extensions must not be treated as authoritative format identifiers.

The application must inspect file contents.

The File Inspector should use multiple identification signals:

1. File signatures and magic bytes.
2. Container headers.
3. MIME information.
4. Internal format structures.
5. Stream metadata.
6. Codec identification.
7. File extension as a secondary hint only.

For example, a file named `video.mp4` must not automatically be assumed to contain H.264 video and AAC audio.

It could contain different codecs, multiple streams, subtitles, or unsupported content.

The application should distinguish:

- Recognized format.
- Recognized container.
- Recognized codec.
- Supported processing operations.
- Unsupported or partially supported content.
- Unknown format.

The format registry must be extensible so additional formats can be introduced later.

## 4.3 File Inspector

The File Inspector should provide a common interface for inspecting files before processing.

For media files, it should expose:

- Container.
- Video codec.
- Audio codec.
- Resolution.
- Duration.
- Frame rate.
- Bitrate.
- Audio channels.
- Sample rate.
- Subtitle streams.
- Stream language.
- Metadata.
- File size.

For images:

- Dimensions.
- Format.
- Color profile.
- Transparency.
- Orientation.
- Metadata.
- Animation information.

For PDFs:

- Page count.
- Page dimensions.
- Encryption status.
- Metadata.
- Document properties.

Inspection must be performed before processing whenever the operation depends on the file's structure.

---

# 5. Engine Architecture

## 5.1 Engine registry

The Engine Manager will maintain a registry of available processing engines.

Each engine descriptor should include:

- Engine identifier.
- Engine name.
- Version.
- Platform compatibility.
- Architecture compatibility.
- Installation source.
- Installation state.
- Supported formats.
- Supported operations.
- Supported codecs.
- Required dependencies.
- Resource requirements.
- Recovery capabilities.
- Metadata capabilities.

The registry must describe actual capabilities, not simply whether an executable exists.

For example, FFmpeg may be installed but lack a required codec or filter.

## 5.2 Engine selection

When a processing request is submitted:

1. Identify the input format and internal structure.
2. Identify the requested operation.
3. Determine the required capabilities.
4. Query the engine registry.
5. Filter incompatible engines.
6. Select the most appropriate engine.
7. Validate resource requirements.
8. Execute the operation.
9. Verify the output.

Engine selection should account for:

- Platform.
- Input format.
- Output format.
- Codec support.
- Required operations.
- Performance.
- Availability.
- Quality requirements.
- Resource consumption.

The application must not silently choose a lower-quality processing route when a requested capability is unavailable.

---

# 6. Linux System and Dependency Management

## 6.1 System Inspector

When the application starts on Linux, it must inspect the host environment.

Detect:

- Operating system.
- Distribution.
- Distribution family.
- Distribution version.
- CPU architecture.
- Runtime environment.
- Relevant system libraries.
- Installed processing dependencies.

The primary distribution identification source should be `/etc/os-release`, with `/usr/lib/os-release` as a fallback.

Important fields include:

- ID
- ID_LIKE
- VERSION_ID
- PRETTY_NAME

Architecture detection should support at least:

- x86_64
- aarch64
- i386 where applicable

The application should also detect whether it is running as a native installation, AppImage, Flatpak, or another supported packaging environment.

## 6.2 Distribution families

The dependency manager should recognize common distribution families.

Examples:

| Distribution | Family | Package manager |
|---|---|---|
| Debian | Debian | APT |
| Ubuntu | Debian | APT |
| Devuan | Debian | APT |
| Linux Mint | Debian/Ubuntu | APT |
| Fedora | Fedora/RHEL | DNF |
| Rocky Linux | RHEL | DNF |
| Arch Linux | Arch | Pacman |
| openSUSE | SUSE | Zypper |

The implementation must not assume that every distribution in a family uses identical package names.

Package installation instructions should be distribution-specific where necessary.

## 6.3 Dependency Manager

The Dependency Manager is responsible for determining whether required external dependencies are installed and usable.

Initial dependencies:

- FFmpeg.
- qpdf.
- LibreOffice.
- Relevant image-processing libraries or alternative engines.

It should check:

- Executable availability.
- Version.
- Execution permissions.
- Required libraries.
- Required codecs and filters.
- Platform compatibility.
- Relevant feature support.

A dependency should not be considered fully available merely because its executable exists.

## 6.4 Startup dependency behavior

Startup sequence:

1. Start the application.
2. Inspect the operating system.
3. Detect distribution and architecture.
4. Initialize the Dependency Manager.
5. Detect installed dependencies.
6. Validate engine capabilities.
7. Update module availability.
8. Present the dependency interface if required.

The application should not unnecessarily block all modules because one optional dependency is missing.

Instead, dependency requirements should be associated with individual modules and operations.

Examples:

- Missing FFmpeg: Video Studio and Audio Studio functions requiring FFmpeg are unavailable.
- Missing qpdf: qpdf-dependent PDF operations are unavailable.
- Missing LibreOffice: Office-to-PDF conversion is unavailable.
- Missing an optional image library: the Image Studio may still use another compatible engine.

## 6.5 Dependency interface

The application must provide a dedicated system requirements/dependencies page.

It should show:

- Detected operating system.
- Distribution.
- Architecture.
- Installed dependencies.
- Missing dependencies.
- Incompatible versions.
- Affected modules.
- Required versions.
- Distribution-specific installation commands.
- A recheck action.

Users should be able to copy installation commands and open relevant system package-management tools.

The application must not silently execute privileged package-management commands.

After installation, users should be able to recheck dependencies without restarting the entire application.

## 6.6 Dependency gating

Module availability must be capability-based.

A missing optional dependency should not make unrelated modules unavailable.

If an operation requires a dependency that is missing, the application should explain the requirement and provide the relevant installation instructions.

---

# 7. Processing Engines by Platform

## 7.1 Linux multimedia engine

Initial implementation: FFmpeg CLI.

Dart should execute FFmpeg through process management, using `Process.start` rather than blocking execution.

Responsibilities:

- Start and stop processes.
- Capture stdout and stderr.
- Parse progress.
- Track execution time.
- Track encoding speed.
- Track frame progress.
- Handle errors.
- Support cancellation.
- Verify output.

Direct integration with FFmpeg's C libraries through FFI is not required initially.

A native integration may be considered later if the CLI approach creates measurable limitations.

## 7.2 Android multimedia engine

Initial video engine: AndroidX Media3 Transformer.

Media3 Transformer will handle initial supported video operations, including:

- Trimming.
- Cropping.
- Resizing.
- Rotation.
- Supported effects.
- Encoding.

Advanced functionality may later use an optional FFmpeg native engine.

The Android engine registry must distinguish between operations supported by Media3 and those requiring the optional engine.

## 7.3 Linux PDF engine

Initial implementation: qpdf.

Responsibilities include:

- Merge.
- Split.
- Page extraction.
- Page organization.
- Rotation.
- PDF structural operations.
- Other supported qpdf operations.

Additional tools may be evaluated for compression and image optimization.

## 7.4 Android PDF engine

Initial implementation: PDFBox-Android.

Android's native PdfRenderer may be used for rendering and previews.

The implementation must evaluate:

- Incremental application size.
- Memory usage.
- Performance.
- Large-document behavior.
- Encryption support.
- Preservation of annotations and document structures.
- Feature coverage.
- Dependency and licensing implications.

PDFBox-Android should be integrated behind the shared PdfEngine interface.

## 7.5 Linux document engine

Use LibreOffice in headless mode for supported document conversions.

The application should:

- Validate the input.
- Invoke the conversion process.
- Track progress where possible.
- Capture errors.
- Validate the output PDF.
- Preserve the original input.

## 7.6 Image engines

Linux may use libvips and libheif where available.

Android should use native platform image capabilities or compatible libraries.

The Engine Manager should select a suitable engine based on the format and required operation.

---

# 8. Video Processing and Loss-Aware Cropping

## 8.1 Core objective

Loss-Aware Cropping is a central differentiating feature.

Its purpose is to avoid unnecessary output-file inflation during cropping and related video transformations.

The system should attempt to reduce output size where feasible while preserving acceptable visual quality.

It must not promise that every cropped video will necessarily become smaller.

Removing pixels does not mathematically guarantee fewer compressed bytes.

Compression depends on codec behavior, bitrate, frame complexity, encoding parameters, and other factors.

## 8.2 Input inspection

Before cropping, inspect:

- Original file size.
- Duration.
- Container.
- Video codec.
- Video bitrate.
- Resolution.
- Frame rate.
- Pixel format.
- Audio streams.
- Audio bitrate.
- Subtitle streams.
- Metadata.
- Other relevant streams.

The original file should remain unchanged.

## 8.3 Crop behavior

Cropping must be distinguished from resizing.

Cropping removes spatial regions from each frame.

Resizing changes the dimensions of the resulting frame.

The application must not automatically upscale cropped footage.

If a user requests cropping without resizing, the output dimensions should reflect the crop dimensions.

The interface should communicate the resulting resolution.

## 8.4 Encoding strategy

The encoding strategy should:

1. Inspect the original encoding parameters.
2. Determine the resulting dimensions.
3. Preserve frame rate unless explicitly changed.
4. Preserve compatible audio streams through stream copying where possible.
5. Avoid unnecessary audio re-encoding.
6. Avoid unnecessary upscaling.
7. Estimate an appropriate video bitrate or quality setting.
8. Account for codec efficiency and content complexity.
9. Encode the output.
10. Verify the result.

Original bitrate may be used as a reference, but should not be blindly reused as the output bitrate.

The system should consider:

- Original resolution.
- Cropped resolution.
- Duration.
- Frame rate.
- Codec.
- Content complexity.
- Desired quality.
- Target output size, if provided.

## 8.5 Quality and size policy

Default behavior:

**Prefer a smaller file when feasible while preserving acceptable quality.**

The user should be able to configure a quality floor.

If a target output size cannot be achieved without unacceptable quality degradation, the application must communicate that limitation.

The application must not silently produce severely degraded output simply to meet a requested size.

Where practical, objective quality metrics such as VMAF may be evaluated, but they should not be treated as universally available or definitive.

## 8.6 Two-stage encoding and verification

A potential processing strategy:

**Stage 1: Estimate**

- Analyze the original video.
- Calculate the crop dimensions.
- Estimate suitable encoding parameters.
- Estimate the likely output size.

**Stage 2: Encode and verify**

- Encode the output.
- Inspect the result.
- Compare file size and quality indicators.
- Verify duration and dimensions.
- Check stream integrity.
- Retry with adjusted parameters when justified.

Retries should be bounded by configurable limits.

## 8.7 Acceptance requirements

Loss-Aware Cropping should:

- Avoid unnecessary output inflation.
- Preserve acceptable visual quality.
- Preserve compatible audio streams where possible.
- Avoid unnecessary frame-rate changes.
- Avoid unnecessary upscaling.
- Verify the resulting file.
- Explain unavoidable trade-offs.

The feature should be considered successful when it avoids unnecessary inflation and achieves smaller outputs when feasible without violating the quality floor.

## 8.8 Containers, codecs, and streams

The application must distinguish:

- Container conversion.
- Codec conversion.
- Stream copying.
- Transcoding.
- Re-encoding.
- Metadata modification.

A container conversion does not necessarily require re-encoding.

If the existing streams are compatible with the destination container, the application should prefer remuxing or stream copying.

If they are incompatible, transcoding may be necessary.

The user interface should explain when a requested conversion requires re-encoding.

## 8.9 Subtitle handling

Subtitle functionality must distinguish between soft subtitles and burned-in subtitles.

Soft subtitles:

- Exist as separate streams.
- Can be enabled or disabled by the player.
- Do not modify video pixels.
- May be copied or converted between compatible subtitle formats.

Burned-in subtitles:

- Become part of the video image.
- Require video re-encoding.
- Cannot be independently disabled afterward.

SRT should be supported for basic timed text.

ASS/SSA should be considered for advanced styling, including:

- Fonts.
- Font sizes.
- Colors.
- Outlines.
- Positioning.
- Alignment.
- Margins.
- Styling and supported animation.

Container compatibility must be considered.

For example, MKV generally supports richer subtitle formats than MP4, whose common subtitle representation is more restricted.

## 8.10 Metadata

The application should provide explicit metadata policies.

Possible actions:

- Preserve metadata.
- Remove metadata.
- Modify selected metadata.
- Preserve compatible stream metadata.
- Warn when a transformation causes metadata loss.

Metadata modification must be treated separately from video transcoding.

---

# 9. Storage and File Management

## 9.1 Storage Manager responsibilities

The Storage Manager must coordinate storage usage across all studios.

Before a processing job starts, it should estimate:

- Input size.
- Temporary working space.
- Intermediate storage requirements.
- Expected output size.
- Available disk space.
- Additional storage needed for retries.

## 9.2 Temporary files

Temporary files should be associated with processing-job identifiers.

The application must:

- Use predictable internal working directories.
- Avoid modifying original files.
- Clean completed-job temporary artifacts.
- Preserve recoverable artifacts when appropriate.
- Clean abandoned files after verifying they are no longer needed.
- Handle insufficient storage gracefully.

## 9.3 Partial files

Incomplete outputs must never be presented as completed files.

Each output artifact should have a state such as:

- Pending.
- Processing.
- Partial.
- Verified.
- Completed.
- Failed.
- Cancelled.

The application should distinguish between a valid completed output and a recoverable partial output.

## 9.4 File-size management

Storage Manager should track:

- Original size.
- Intermediate size.
- Final size.
- Compression ratio.
- Space consumed by temporary files.
- Space recovered after cleanup.

This information should be available in job history.

---

# 10. Processing Manager and Job Architecture

## 10.1 Processing Manager

The Processing Manager is responsible for orchestrating all long-running processing tasks.

Responsibilities:

- Job creation.
- Validation.
- Engine selection.
- Resource allocation.
- Execution.
- Progress tracking.
- Cancellation.
- Error handling.
- Output verification.
- Job persistence.
- Recovery.

## 10.2 Job lifecycle

Suggested states:

- Created.
- Pending.
- Validating.
- WaitingForEngine.
- WaitingForStorage.
- Processing.
- Checkpointing.
- Verifying.
- Completed.
- Failed.
- Cancelled.
- Interrupted.
- Recoverable.

State transitions must be validated.

A job must not be marked completed until its output has passed the required verification steps.

## 10.3 SQLite persistence

SQLite should store job metadata and execution history.

Suggested information:

- Job ID.
- Module.
- Operation.
- Input references.
- Input metadata.
- Processing parameters.
- Selected engine.
- Engine version.
- Current state.
- Progress.
- Start time.
- End time.
- Temporary file references.
- Output references.
- Error information.
- Checkpoint information.
- Recovery status.

Large media data should not be stored directly in SQLite.

SQLite should store references and metadata, while actual file content remains in the filesystem or platform-managed storage.

## 10.4 Threads and isolates

Heavy processing must not run on Flutter's UI isolate.

Use Dart isolates where appropriate for:

- File inspection.
- Metadata parsing.
- Progress parsing.
- CPU-intensive Dart operations.
- Batch orchestration.

Native engines and external processes may perform their own multithreaded processing.

Concurrency should be limited according to:

- CPU availability.
- Memory usage.
- Processing-engine behavior.
- Storage throughput.
- Battery limitations.

## 10.5 Android background processing

Android must use appropriate platform mechanisms for long-running work.

Evaluate:

- Foreground services.
- WorkManager for deferrable work.
- Native Media3 processing.
- Notifications.
- Platform-specific cancellation.
- Process-death recovery.

Long-running user-initiated media processing may require a foreground service and a visible notification.

Background execution must respect Android's current operating-system restrictions and permissions.

## 10.6 Linux background processing

Linux can manage external processing processes directly.

The application should:

- Maintain process identifiers and job metadata.
- Capture process output.
- Handle cancellation.
- Detect process termination.
- Recover interrupted job records.
- Avoid assuming that an interrupted FFmpeg process can resume automatically.

## 10.7 Chunking and checkpoints

Investigate chunk-based processing and checkpoint persistence.

The architecture should support a processing engine declaring its recovery capabilities:

1. **Restart from beginning:** No safe continuation mechanism exists.
2. **Restart from checkpoint:** Processing can resume from a verified intermediate stage.
3. **True partial continuation:** Processing can continue from previously completed chunks without reprocessing them.

The application must not assume arbitrary media files can be divided into independent chunks.

For video, codec dependencies, frame references, timestamps, audio synchronization, and container indexes may prevent arbitrary chunk-level recovery.

For other operations, such as independent image batches or page-based PDF processing, chunking may be more practical.

Each checkpoint should record:

- Job ID.
- Input identity.
- Input integrity information.
- Engine and version.
- Processing parameters.
- Completed units.
- Intermediate artifact references.
- Checkpoint integrity.
- Recovery compatibility.

A checkpoint must not be reused if the input, processing parameters, or engine version makes it incompatible.

Automatic recovery should initially be conservative.

---

# 11. Engine Manager and Optional Engines

The Engine Manager is responsible for managing available processing engines.

It should:

- Discover installed engines.
- Track engine versions.
- Detect capabilities.
- Validate compatibility.
- Report missing engines.
- Manage optional engine installation where supported.
- Manage updates.
- Validate engine integrity.
- Report incompatible versions.

Linux should initially prefer system-provided dependencies when practical.

Android should initially prefer platform capabilities and the engines already included in the application.

Optional downloadable engines may be introduced later.

Any downloaded engine must have:

- Trusted distribution source.
- Version information.
- Integrity verification.
- Platform and ABI compatibility checks.
- Secure update handling.
- License information.

Android Dynamic Feature Modules should not be confused with arbitrary native engine downloads. Native engine delivery requires its own architecture and integrity controls.

---

# 12. Security and Privacy

## 12.1 Local-first processing

Files should remain on the user's device unless a future feature explicitly requires remote processing and the user authorizes it.

No silent document uploads.

## 12.2 Original file protection

The application must not modify original input files by default.

Processing should use working copies or engine-supported non-destructive operations.

## 12.3 Temporary data

Temporary files must be managed securely.

The application should:

- Avoid unnecessarily retaining sensitive intermediate files.
- Clean temporary files after successful completion.
- Preserve only necessary recovery artifacts.
- Avoid logging sensitive file contents.
- Avoid exposing private paths or document contents in diagnostics.

## 12.4 File validation

Treat input files as untrusted.

The application should validate:

- File structure.
- Size.
- Format.
- Engine compatibility.
- Resource requirements.

It should handle malformed or malicious files without crashing the entire application.

## 12.5 Dependency execution

Linux external processes must be launched with controlled arguments.

Avoid unsafe shell-string construction.

Use argument lists and validate input paths.

The application must not execute privileged installation commands automatically.

---

# 13. Packaging and Distribution

## 13.1 Linux

Initial distribution target: Debian-compatible `.deb`.

The application should be tested on Devuan and Debian-family distributions, while maintaining an extensible distribution-detection system.

Potential future distribution formats:

- AppImage.
- Flatpak.
- Other distribution-specific packages.

Packaging strategy must account for system dependencies, runtime libraries, and sandbox restrictions.

## 13.2 Android

Distribute through APK/AAB.

Account for:

- Supported ABIs.
- Native library size.
- Android version compatibility.
- Storage permissions.
- Background processing restrictions.
- Platform codecs.
- Optional engine delivery.

Avoid bundling unnecessary codecs and native libraries into the base application.

---

# 14. Licensing and Legal Considerations

Licensing must be reviewed before selecting final library builds or distributing the application.

Relevant considerations:

### FFmpeg

- LGPL/GPL build configuration.
- Codec licensing.
- x264 and other GPL components.
- Source-code availability obligations.
- Distribution and linking requirements.

### PDFBox-Android

- Apache 2.0 licensing.
- Third-party dependency licenses.
- Notices and attribution requirements.

### qpdf

- Library and executable licensing obligations.
- Distribution of modified or bundled versions.

### LibreOffice

- License and distribution requirements.
- Packaging and external dependency considerations.

### Image libraries

- libvips.
- libheif.
- Associated codecs and dependencies.

### Other libraries

Every new dependency must undergo a license review.

Maintain a dependency inventory containing:

- Library name.
- Version.
- License.
- Source.
- Distribution method.
- Modifications.
- Required notices.
- Source-code obligations.
- Patent considerations where applicable.

The application must not assume that an open-source license automatically resolves codec patent or commercial distribution considerations.

---

# 15. Testing and Quality Assurance

## 15.1 Test strategy

Testing must cover:

- Unit tests.
- Engine adapter tests.
- Integration tests.
- Cross-platform tests.
- File integrity tests.
- Performance tests.
- Recovery tests.
- Storage tests.
- UI tests.

## 15.2 Test corpus

Maintain a curated collection of test files.

Include:

- Different video containers.
- Different video codecs.
- Different audio codecs.
- Multiple audio streams.
- Multiple subtitle streams.
- Different subtitle formats.
- Large and small PDFs.
- Encrypted PDFs.
- PDFs with forms and annotations.
- Office documents.
- Images with transparency.
- Images with EXIF orientation.
- Images with ICC profiles.
- HEIC files.
- Malformed files.
- Unusually large files.

## 15.3 Video acceptance tests

Verify:

- Output dimensions.
- Duration.
- Frame rate.
- Audio synchronization.
- Subtitle behavior.
- Stream preservation.
- Output file size.
- Playback integrity.
- Visual quality.
- Metadata behavior.

Loss-Aware Cropping tests should include cases where:

- The output becomes smaller.
- The output remains approximately the same size.
- The output would otherwise become larger.
- The target size is impossible without unacceptable quality loss.

The system must report these cases accurately.

## 15.4 PDF acceptance tests

Verify:

- Page count.
- Page order.
- Page dimensions.
- Rotation.
- Encryption.
- Metadata.
- Annotations.
- Bookmarks.
- Links.
- Forms where supported.
- Structural integrity.

## 15.5 Image acceptance tests

Verify:

- Dimensions.
- Orientation.
- Transparency.
- Color fidelity.
- ICC profiles.
- Metadata preservation or removal.
- Animation behavior.

## 15.6 Storage and recovery tests

Verify:

- Insufficient storage handling.
- Temporary file cleanup.
- Interrupted jobs.
- Application restart.
- Partial outputs.
- Checkpoint validation.
- Recovery compatibility.
- No accidental deletion of originals.

## 15.7 Cross-platform tests

The same functional test corpus should be used on Linux and Android where the corresponding operation is supported.

Expected output differences should be documented when different engines produce different encoding or rendering results.

---

# 16. MVP Scope

The first release should prioritize a reliable foundation rather than attempting every possible file format and operation.

## 16.1 MVP modules

| Module | Initial scope |
|---|---|
| PDF Studio | Core manipulation operations |
| Document Studio | Linux Office-to-PDF and Markdown-to-PDF |
| Image Studio | Common format conversion and resizing |
| Video Studio | Trim, crop, resize, compression, basic conversion |
| Audio Studio | Basic conversion and extraction |
| File Inspector | Content-based identification and metadata inspection |
| Storage Manager | Working files, output management, cleanup |
| Engine Manager | Engine discovery and capability registry |
| Dependency Manager | Linux system and dependency detection |
| Processing Manager | Job execution, persistence, cancellation and history |

Android Office conversion is unavailable in the MVP.

Advanced subtitle styling, extensive format support, cloud conversion, and sophisticated recovery mechanisms can be developed in later phases.

## 16.2 Initial common format coverage

| Category | Initial formats |
|---|---|
| Video containers | MP4, MKV, WebM, MOV |
| Audio | MP3, WAV, FLAC, AAC, M4A, OGG, Opus |
| Images | JPG, PNG, WebP, HEIC/HEIF |
| Documents | DOCX, PPTX, XLSX, ODT, ODS, ODP, Markdown |
| PDF | PDF |

The registry must permit future additions without requiring major architectural changes.

---

# 17. Development Phases

## Phase 1: Application foundation

- Flutter project structure.
- Provider-based state management.
- Shared domain models.
- FileReference abstraction.
- SQLite setup.
- Module navigation.
- Platform detection.

## Phase 2: System and engine infrastructure

- Linux System Inspector.
- Dependency Manager.
- Engine Manager.
- Capability registry.
- Module availability gating.
- Android platform capability detection.

## Phase 3: File and storage infrastructure

- File Inspector.
- Content-based format detection.
- Storage Manager.
- Temporary file management.
- Output management.
- Storage estimates.

## Phase 4: Processing infrastructure

- Processing Manager.
- Job lifecycle.
- SQLite job persistence.
- Progress reporting.
- Cancellation.
- Error handling.
- Output verification.

## Phase 5: Initial PDF and image functionality

- Linux qpdf integration.
- Android PDFBox-Android integration.
- Android PdfRenderer integration where useful.
- Image engine adapters.
- Core PDF operations.
- Core image conversion.

## Phase 6: Multimedia functionality

- Linux FFmpeg integration.
- Android Media3 Transformer integration.
- Video inspection.
- Trim, crop, resize, compression.
- Audio conversion.
- Stream-copy and transcoding decisions.

## Phase 7: Loss-Aware Cropping

- Input analysis.
- Crop geometry.
- Bitrate/quality estimation.
- Encoding profiles.
- Output verification.
- Retry strategy.
- Quality-floor configuration.
- Acceptance testing.

## Phase 8: Document conversion

- Linux LibreOffice integration.
- Markdown-to-PDF.
- Android module availability behavior.

## Phase 9: Recovery and optimization

- Background processing.
- Android foreground services.
- Linux process recovery.
- Checkpoint persistence.
- Partial processing evaluation.
- Resource and concurrency management.

## Phase 10: Packaging and release

- Linux `.deb`.
- Android AAB/APK.
- Dependency validation.
- License audit.
- Cross-platform test suite.
- Performance testing.

---

# 18. Open Technical Investigations

The following decisions should remain open until supported by prototypes or measurements.

1. Exact qpdf Android package-size evaluation is no longer required for the initial implementation because PDFBox-Android has been selected.
2. PDFBox-Android memory consumption and large-document performance.
3. PDFBox feature coverage for encryption, annotations, bookmarks, and forms.
4. FFmpeg Linux dependency and packaging strategy.
5. Android optional FFmpeg engine delivery.
6. Exact Linux image-processing dependency set.
7. Storage estimation accuracy for different processing operations.
8. Safe checkpoint and partial-resumption mechanisms for individual engines.
9. Android background processing behavior across supported OS versions.
10. Quality-estimation strategy for Loss-Aware Cropping.
11. Optional engine installation and update mechanism.
12. Final supported Linux distribution and architecture matrix.

These investigations must not be treated as reasons to delay the foundational architecture. The interfaces should accommodate different implementation choices.

---

# 19. Architectural Acceptance Criteria

The architecture is considered ready for feature implementation when:

1. The same shared module interface can call different platform engines.
2. The application can identify files without relying on extensions.
3. The system can identify missing dependencies and affected modules.
4. Unrelated modules remain usable when optional dependencies are missing.
5. Processing jobs are persisted independently of the UI.
6. Long-running operations do not block the Flutter main isolate.
7. Original files remain protected.
8. Temporary and partial files are managed through the Storage Manager.
9. Engine selection is capability-based.
10. Processing results are verified before completion.
11. Loss-Aware Cropping can evaluate output size and quality trade-offs.
12. The dependency and licensing inventory is maintained.
13. New engines and formats can be added without restructuring the entire application.

---

# 20. Final Architectural Position

Universal Utility will be a modular Flutter application with shared Dart business logic and platform-specific processing engines.

The initial platform strategy is:

**Linux**
- FFmpeg CLI for multimedia.
- qpdf for PDF manipulation.
- LibreOffice for Office document conversion.
- Suitable native image-processing libraries.
- Explicit system and dependency inspection.

**Android**
- Media3 Transformer for initial video processing.
- PDFBox-Android for PDF manipulation.
- Android PdfRenderer for rendering where appropriate.
- Native image capabilities and compatible image libraries.
- No Office document conversion in the MVP.

**Shared application infrastructure**
- Provider state management.
- SQLite job persistence.
- File Inspector.
- Storage Manager.
- Processing Manager.
- Engine Manager.
- Dependency Manager.
- Shared processing interfaces.
- Capability-based engine selection.

The central design objective is to keep the application unified at the product and application-architecture levels without forcing every platform to use the same underlying processing implementation.

The system should be extensible, resource-aware, recoverable where technically possible, and transparent about the actual operations performed on user files.
