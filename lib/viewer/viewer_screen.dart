import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../theme/app_theme.dart';
import '../window/focus_tint.dart';

/// PDF 보기 화면: 본문 + 접을 수 있는 썸네일 사이드바, 쪽 번호와 확대/축소.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path});

  final String path;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = PdfViewerController();
  bool _showThumbnails = true;

  String get _name => widget.path.split(RegExp(r'[\\/]')).last;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(_name, overflow: TextOverflow.ellipsis),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              if (!_controller.isReady) return const SizedBox.shrink();
              return Text(l10n.viewerPageOf(_controller.pageNumber ?? 1, _controller.pageCount));
            },
          ),
          IconButton(
            tooltip: l10n.viewerZoomOut,
            icon: const Icon(Icons.zoom_out_rounded),
            onPressed: () => _controller.isReady ? _controller.zoomDown() : null,
          ),
          IconButton(
            tooltip: l10n.viewerZoomIn,
            icon: const Icon(Icons.zoom_in_rounded),
            onPressed: () => _controller.isReady ? _controller.zoomUp() : null,
          ),
          IconButton(
            tooltip: l10n.viewerEditPages,
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => PageToolsScreen(initialPath: widget.path))),
          ),
          IconButton(
            tooltip: l10n.viewerThumbnails,
            isSelected: _showThumbnails,
            icon: const Icon(Icons.view_sidebar_outlined),
            selectedIcon: const Icon(Icons.view_sidebar_rounded),
            onPressed: () => setState(() => _showThumbnails = !_showThumbnails),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Row(
        children: [
          if (_showThumbnails)
            SizedBox(
              width: 160,
              child: PdfDocumentViewBuilder.file(
                widget.path,
                builder: (context, document) {
                  if (document == null) return const SizedBox.shrink();
                  return ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    itemCount: document.pages.length,
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: InkWell(
                        onTap: () => _controller.goToPage(pageNumber: index + 1),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 180,
                              child: PdfPageView(document: document, pageNumber: index + 1),
                            ),
                            Text('${index + 1}'),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: PdfViewer.file(
              widget.path,
              controller: _controller,
              params: PdfViewerParams(
                errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(child: Text(l10n.openFailed)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
