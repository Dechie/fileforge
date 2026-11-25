# FileForge

FileForge is a local file utility for Linux. It converts and edits PDFs, office documents, images, video, and audio on the machine where it runs. Finished files stay in your documents folder.

## Screens

### Home

The home screen opens the five studios and lists work that is running.

![Home](<screenshots/image 0 main.jpg>)

### PDF Studio

Merge, split, extract, reorder, rotate, delete, compress, watermark, number, and protect PDF pages. qpdf does the work.

![PDF Studio](<screenshots/image 1 pdf edit.jpg>)

### Document Studio

Turn office files and Markdown into PDF with LibreOffice. Markdown shows a preview before conversion.

![Document Studio](<screenshots/image 2 files to pdf.jpg>)

### Image Studio

Convert, resize, compress, and strip metadata from JPEG, PNG, and WebP. FFmpeg encodes the stills.

![Image Studio](<screenshots/image 3 images.jpg>)

### Video Studio

Trim, crop, resize, compress, change containers, add or extract subtitles, extract frames, and pull or remove audio.

![Video Studio](<screenshots/image 4 video.jpg>)

### Audio Studio

Convert, compress, and trim audio, or extract a soundtrack from a video.

![Audio Studio](<screenshots/image 5 audio.jpg>)

### System

System shows the OS and whether FFmpeg, qpdf, and LibreOffice are installed.

![System and dependencies](<screenshots/image 6 settings.jpg>)

## Requirements

Install the tools for the studios you use:

| Studio | Tool | Debian and Ubuntu |
| --- | --- | --- |
| Video, audio, and images | FFmpeg | `sudo apt install ffmpeg` |
| PDF | qpdf | `sudo apt install qpdf` |
| Documents | LibreOffice | `sudo apt install libreoffice` |

Fedora: `sudo dnf install ffmpeg qpdf libreoffice`

Arch: `sudo pacman -S ffmpeg qpdf libreoffice-still`

openSUSE: `sudo zypper install ffmpeg qpdf libreoffice`

Image Studio uses the JPEG, PNG, and WebP encoders in FFmpeg. HEIC needs a HEIF decoder, which this build does not include. Animated images are refused so they are not flattened to one frame.

## Run

```bash
flutter pub get
flutter run -d linux
```

## Saved files

Each studio writes into its own folder under the app documents directory:

`~/Documents/FileForge/output/{pdf,documents,images,video,audio}`

Open the gallery in a studio to see files already saved there. The path is shown at the top of the gallery.
