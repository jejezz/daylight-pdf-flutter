<!-- From jejezz/application-release-templates common/tool/readme @ conventions-v1. -->

<p align="center">
  <img src="assets/icon/app_icon.png" width="128" alt="Daylight PDF icon">
</p>

<h1 align="center">Daylight PDF</h1>

<p align="center">
  A desktop app that <b>converts images, SVG and PDF-compatible .ai files to PDF</b>, with viewing, annotations and page tools in one place.
</p>

<p align="center">
  <a href="https://github.com/jejezz/daylight-pdf-flutter/releases/latest"><img src="https://img.shields.io/github/v/release/jejezz/daylight-pdf-flutter?style=flat-square&color=4c9dff" alt="Latest release"></a>
  <a href="https://github.com/jejezz/daylight-pdf-flutter/releases"><img src="https://img.shields.io/github/downloads/jejezz/daylight-pdf-flutter/total?style=flat-square&color=7c5cff" alt="Downloads"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%C2%B7%20Windows%20%C2%B7%20Linux-34d399?style=flat-square" alt="macOS · Windows · Linux">
  <img src="https://img.shields.io/badge/built%20with-Flutter-02569b?style=flat-square" alt="Flutter">
  <a href="LICENSE"><img src="https://img.shields.io/github/license/jejezz/daylight-pdf-flutter?style=flat-square" alt="MIT license"></a>
</p>

<p align="center">
  <b>English</b> · <a href="README.ko.md">한국어</a>
</p>

<p align="center">
  <img src="docs/screenshots/demo.gif" width="720" alt="Daylight PDF demo: convert files, arrange pages, annotate and search, then print">
</p>

## Features

- **Convert** — PNG, JPG, BMP, GIF, WebP, TIFF, SVG and PDF-compatible `.ai` to PDF (one PDF per file, or merge images into one); PDF pages to PNG or JPG at 72, 150 or 300 dpi. Drop files in, and a queue shows progress and failures per file.
- **View** — fast PDFium rendering with thumbnails, an outline sidebar, text search (`⌘F`), fit width / fit page / actual size, and a password prompt for protected PDFs. Your last ten files are one click away on the home screen.
- **Annotate** — highlight, underline, notes, freehand, rectangle and circle in six colors. Undo with `⌘Z`; click a note to read or edit it. Annotations are standard PDF annotations, so they show up in other viewers too, notes with their own icon.
- **Page tools** — merge PDFs, split every N pages or by ranges, rotate, delete, drag to reorder, and save just the pages you select.
- **Print** — a preview with page range, odd/even, reverse, annotations on/off, fit or actual size, margins, paper, **2/4/6/9 pages per sheet**, **booklet**, page numbers, watermark and forced black-and-white, then the system print dialog for printer, copies and duplex.
- **Light & dark, English & 한국어** — follows the system, or pick one in the toolbar

<p align="center">
  <img src="docs/screenshots/viewer.png" width="360" alt="Viewer with highlights, a note, text search and the outline sidebar">
  <img src="docs/screenshots/convert.png" width="360" alt="Convert screen with a queue of images, SVG and PDF files">
</p>
<p align="center">
  <img src="docs/screenshots/pages.png" width="360" alt="Page tools: a grid of page thumbnails with two pages selected">
  <img src="docs/screenshots/print.png" width="360" alt="Print settings with a 4-up preview, margins, booklet and watermark options">
</p>

## Install

Download from [**Releases**](https://github.com/jejezz/daylight-pdf-flutter/releases/latest):

| OS | File |
|---|---|
| macOS 12.0+ | `DaylightPDF-<version>-macos-universal.dmg` — open it and drag Daylight PDF to Applications |
| Windows 10/11 (x64) | `DaylightPDF-<version>-windows-x64-setup.exe` |
| Linux (x64) | `DaylightPDF-<version>-linux-x64.tar.gz` — extract and run `./install.sh` (`--remove` to uninstall) |

**Windows:** the installer isn't code-signed yet, so SmartScreen says "Windows protected your PC" — choose **More info → Run anyway**.

## How it works

Rendering, page assembly and annotations all run on [PDFium](https://pdfium.googlesource.com/pdfium/) (through [pdfrx](https://pub.dev/packages/pdfrx)), so nothing is re-encoded when you merge, split or annotate: annotations are written with PDFium's annotation API, and a note's icon is an SVG converted into the annotation's own appearance, which is why it looks the same elsewhere. Printing prepares the PDF first — page selection, scaling and margins, n-up or booklet imposition, page numbers and watermark — and then hands the result to the operating system's print dialog.

Good to know: there is no direct text editing, HEIC images aren't supported, an `.ai` file must be saved with "Create PDF Compatible File", and the page tools can't open password-protected PDFs yet.

## Development

```bash
flutter pub get
flutter run -d macos
```

Nothing else to install: PDFium is bundled by `pdfrx`. Run `flutter test` for the unit tests; the tests that need the real PDF engine live in `integration_test/` and run in the app, one file at a time (for example `flutter test integration_test/convert_test.dart -d macos`). Screenshots: `flutter test integration_test/readme_shots_test.dart -d macos`, then `tool/readme/frame.py` and `tool/readme/make_demo_gif.py`.

Releasing: `scripts/bump-version.sh patch`, merge, then tag `vX.Y.Z` — CI builds and publishes every platform. Rules: [application-release-templates/conventions](https://github.com/jejezz/application-release-templates/tree/main/conventions).

## Credits

- Rendering: [PDFium](https://pdfium.googlesource.com/pdfium/) via [pdfrx](https://pub.dev/packages/pdfrx)
- Font: [SeoulNamsan](https://www.seoul.go.kr/seoul/font.do) (Seoul Metropolitan Government)
- Icons: [Icons8](https://icons8.com)

## License

[MIT](LICENSE) © 2026 Jongyun Ahn
