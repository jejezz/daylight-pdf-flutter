# pdfrx 2.6.5 (patched copy)

Upstream: https://pub.dev/packages/pdfrx/versions/2.6.5 — MIT, see LICENSE.

Only `lib/` is kept (the `assets/` folder is web-only). One change, marked `DAYLIGHT PATCH` in
`lib/src/widgets/pdf_viewer.dart`: a page that was reloaded (`PdfPageStatusModified`) is re-rendered even when its
size is unchanged. Upstream treats "same size" as "same picture", so annotation edits never showed up without
flushing every page's cache. The old picture stays on screen until the new one is ready.

When upgrading pdfrx, re-apply that patch (or drop this folder and the `dependency_overrides` in pubspec.yaml if
upstream handles it).
