import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../convert/conversion_error.dart';
import '../convert/error_text.dart';
import '../engine/annotations/annotation_specs.dart';
import '../engine/annotations/pdfium_annotations.dart';
import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../pages/pdf_dialogs.dart';
import '../theme/app_theme.dart';
import '../window/focus_tint.dart';
import 'annotation_panel.dart';
import 'annotation_state.dart';
import 'annotation_toolbar.dart';
import 'draw_layer.dart';
import 'text_boxes.dart';

/// PDF 보기 화면: 본문 + 접을 수 있는 썸네일 사이드바, 쪽 번호와 확대/축소, 주석 도구와 주석 목록.
/// 주석은 열린 문서에 바로 쓰이고 [저장]으로 새 파일(또는 같은 이름)에 담긴다.
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({super.key, required this.path});

  final String path;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  final _controller = PdfViewerController();
  final _annotations = AnnotationState();
  bool _showThumbnails = true;
  bool _showList = false;
  bool _allowPop = false;

  String get _name => p.basename(widget.path);

  PdfDocument? get _document => _controller.isReady ? _controller.document : null;

  @override
  void dispose() {
    _annotations.dispose();
    super.dispose();
  }

  /// 선택한 글자에 형광펜/밑줄을 단다.
  Future<void> _applyToSelection({required bool underline}) async {
    final l10n = AppLocalizations.of(context);
    final document = _document;
    if (document == null) return;
    final ranges = await _controller.textSelectionDelegate.getSelectedTextRanges();
    final specs = <PdfAnnotationSpec>[];
    for (final range in ranges) {
      final boxes = lineBoxes(range.pageText.charRects, range.start, range.end);
      if (boxes.isEmpty) continue;
      final pageIndex = range.pageNumber - 1;
      specs.add(
        underline
            ? UnderlineSpec(pageIndex: pageIndex, color: _annotations.color, boxes: boxes)
            : HighlightSpec(pageIndex: pageIndex, color: _annotations.color, boxes: boxes),
      );
    }
    if (specs.isEmpty) {
      if (mounted) showMessage(context, l10n.annotSelectTextFirst);
      return;
    }
    await _add(specs);
    await _controller.textSelectionDelegate.clearTextSelection();
  }

  Future<void> _add(List<PdfAnnotationSpec> specs) async {
    final document = _document;
    if (document == null) return;
    try {
      await _annotations.add(document, specs);
    } on Object {
      if (mounted) showMessage(context, AppLocalizations.of(context).annotFailed);
    }
  }

  Future<void> _addNote(int pageIndex, PdfPoint at) async {
    final l10n = AppLocalizations.of(context);
    final text = await showDialog<String>(
      context: context,
      builder: (context) {
        final field = TextEditingController();
        return AlertDialog(
          title: Text(l10n.annotNoteTitle),
          content: TextField(
            controller: field,
            autofocus: true,
            maxLines: 5,
            minLines: 2,
            decoration: InputDecoration(hintText: l10n.annotNoteHint),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
            FilledButton(onPressed: () => Navigator.pop(context, field.text.trim()), child: Text(l10n.annotNoteAdd)),
          ],
        );
      },
    );
    if (text == null || text.isEmpty) return;
    await _add([
      NoteSpec(
        pageIndex: pageIndex,
        color: _annotations.color,
        x: at.x,
        y: (at.y - 24).clamp(0, double.infinity),
        text: text,
      ),
    ]);
  }

  Future<void> _delete(ReadAnnotation annotation) async {
    final document = _document;
    if (document == null) return;
    try {
      await _annotations.remove(document, annotation);
    } on Object {
      if (mounted) showMessage(context, AppLocalizations.of(context).annotFailed);
    }
  }

  /// 주석이 든 PDF를 저장한다. 저장했으면 true.
  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context);
    final document = _document;
    if (document == null) return false;
    final target = await pickPdfSavePath(
      l10n,
      suggestedName: '${p.basenameWithoutExtension(widget.path)}-annotated.pdf',
      initialDirectory: p.dirname(widget.path),
    );
    if (target == null || !mounted) return false;
    try {
      final bytes = await document.encodePdf();
      final temp = File('$target.tmp')..writeAsBytesSync(bytes, flush: true);
      temp.renameSync(target);
    } on FileSystemException {
      if (mounted) {
        showMessage(
          context,
          conversionErrorText(l10n, ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(target))),
        );
      }
      return false;
    }
    _annotations.markSaved();
    if (mounted) showMessage(context, l10n.pagesSaved(p.basename(target)));
    return true;
  }

  /// 저장하지 않은 주석이 있으면 나가기 전에 묻는다.
  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final choice = await showDialog<_Leave>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.annotUnsavedTitle),
        content: Text(l10n.annotUnsavedBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, _Leave.stay), child: Text(l10n.commonCancel)),
          TextButton(onPressed: () => Navigator.pop(context, _Leave.discard), child: Text(l10n.annotDiscard)),
          FilledButton(onPressed: () => Navigator.pop(context, _Leave.save), child: Text(l10n.annotSave)),
        ],
      ),
    );
    if (!mounted || choice == null || choice == _Leave.stay) return;
    if (choice == _Leave.save && !await _save()) return;
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: _annotations,
      builder: (context, _) => PopScope(
        canPop: _allowPop || !_annotations.dirty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmLeave();
        },
        child: Scaffold(
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
                tooltip: l10n.annotSave,
                icon: Icon(_annotations.dirty ? Icons.save_rounded : Icons.save_outlined),
                onPressed: _annotations.busy ? null : _save,
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
          body: Column(
            children: [
              SizedBox(
                height: 44,
                child: AnnotationToolbar(
                  state: _annotations,
                  onHighlight: () => _applyToSelection(underline: false),
                  onUnderline: () => _applyToSelection(underline: true),
                  showList: _showList,
                  onToggleList: () => setState(() => _showList = !_showList),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: _content(l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AppLocalizations l10n) {
    return Row(
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
          child: Stack(
            children: [
              PdfViewer.file(
                widget.path,
                controller: _controller,
                params: PdfViewerParams(
                  // 그리는 도구가 켜져 있으면 끌기는 그리기에 쓰이므로 화면 끌기를 끈다 (휠 스크롤·확대는 그대로).
                  panEnabled: !_annotations.drawing,
                  // 쪽 크기가 같으면 pdfrx가 이미 그린 쪽을 다시 그리지 않는다. 이 값이 바뀌면 이미지 캐시를 비우므로,
                  // 주석이 바뀔 때마다 (둘 다 주석을 그리는) 두 모드를 번갈아 써서 본문을 새로 그리게 한다.
                  annotationRenderingMode: _annotations.revision.isOdd
                      ? PdfAnnotationRenderingMode.annotation
                      : PdfAnnotationRenderingMode.annotationAndForms,
                  onViewerReady: (document, controller) => _annotations.refresh(document),
                  errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(child: Text(l10n.openFailed)),
                ),
              ),
              if (_annotations.drawing)
                Positioned.fill(
                  child: DrawLayer(
                    controller: _controller,
                    state: _annotations,
                    onAdd: (spec) => _add([spec]),
                    onNote: _addNote,
                  ),
                ),
            ],
          ),
        ),
        if (_showList)
          SizedBox(
            width: 260,
            child: AnnotationPanel(
              state: _annotations,
              onJump: (page) => _controller.goToPage(pageNumber: page),
              onDelete: _delete,
            ),
          ),
      ],
    );
  }
}

enum _Leave { stay, discard, save }
