# pdfrx 2.6.5 (patched copy)

Upstream: https://pub.dev/packages/pdfrx/versions/2.6.5 — MIT, see LICENSE.

Only `lib/` is kept (the `assets/` folder is web-only). Two changes, both marked `DAYLIGHT PATCH`.

**1. Re-render reloaded pages** (`lib/src/widgets/pdf_viewer.dart`): a page that was reloaded (`PdfPageStatusModified`) is re-rendered even when its
size is unchanged. Upstream treats "same size" as "same picture", so annotation edits never showed up without
flushing every page's cache. The old picture stays on screen until the new one is ready.


**2. `PdfViewerParams.interactionDevices`** (`pdf_viewer_params.dart`, `pdf_viewer.dart`, `interactive_viewer.dart`):
which pointer devices may pan and zoom the view (`null` = all, the upstream behaviour). It is passed to the viewer's
`GestureDetector.supportedDevices`. Daylight uses it so that, while a stylus draws, only fingers move the page.
Upstream has no way to tell a stylus drag from a finger drag.

When upgrading pdfrx, re-apply both patches (or drop this folder and the `dependency_overrides` in pubspec.yaml if
upstream handles them).
