# pdfrx_engine 0.6.1 (patched copy)

Upstream: https://pub.dev/packages/pdfrx_engine/versions/0.6.1 — MIT, see LICENSE. Only `lib/` is kept.

One change in `lib/src/native/pdfrx_pdfium.dart`, marked `DAYLIGHT PATCH`:

**Korean PDFs that do not embed their font** (e.g. 굴림 `/BaseFont /±¼¸²`, `UniKS-UCS2-H`): PDFium asks the system-font
mapper for the face by its raw CP949 bytes. Upstream decoded the name with strict UTF-8, which threw inside the native
callback, so the request vanished: no font, no glyphs, and not even text extraction. Now the name is decoded as UTF-8
or, if that fails, Latin-1 (so the lookup/"missing font" event works), and `pdfrxSetCharsetFallbackFont(charset:, filePath:)`
registers a substitute used for any face in that charset that nothing else matched. The app calls it at startup
(`lib/platform/pdf_fallback_fonts.dart`, Hangul = charset 129).

When upgrading, re-apply it or drop this folder and the `dependency_overrides` entry in pubspec.yaml if upstream fixes it.
