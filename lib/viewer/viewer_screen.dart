import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey, rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../convert/conversion_error.dart';
import '../convert/error_text.dart';
import '../engine/annotations/annotation_specs.dart';
import '../engine/annotations/pdfium_annotations.dart';
import '../l10n/app_localizations.dart';
import '../pages/page_tools_screen.dart';
import '../platform/platform_kind.dart';
import '../pages/pdf_dialogs.dart';
import '../print/print_dialog.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_thumbnail.dart';
import '../widgets/status_pill.dart';
import '../window/focus_tint.dart';
import 'annotation_panel.dart';
import 'annotation_state.dart';
import 'annotation_toolbar.dart';
import 'draw_layer.dart';
import 'note_dialog.dart';
import 'outline_panel.dart';
import 'password_dialog.dart';
import 'search_bar.dart';
import 'note_hit.dart';
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

  /// 글자 찾기. 문서가 열린 뒤에야 만들 수 있다 (`onViewerReady`).
  PdfTextSearcher? _searcher;
  final _annotations = AnnotationState();
  bool _showThumbnails = true;
  bool _showSearch = false;
  _Sidebar _sidebar = _Sidebar.pages;
  List<PdfOutlineNode> _outline = const [];
  int _passwordAttempts = 0;
  bool _showList = false;
  bool _allowPop = false;

  /// 새 메모에 넣을 아이콘 SVG (PDF 안의 메모 모양이 된다). 읽기 전이거나 실패하면 null → 뷰어 기본 아이콘.
  String? _noteIconSvg;

  String get _name => p.basename(widget.path);

  PdfDocument? get _document => _controller.isReady ? _controller.document : null;

  @override
  void initState() {
    super.initState();
    _loadNoteIcon();
  }

  Future<void> _loadNoteIcon() async {
    try {
      _noteIconSvg = await rootBundle.loadString('assets/annotations/note_icon.svg');
    } on Object {
      _noteIconSvg = null; // 아이콘을 못 읽어도 메모는 달 수 있다 (뷰어 기본 아이콘)
    }
  }

  @override
  void dispose() {
    _searcher?.dispose();
    _annotations.dispose();
    super.dispose();
  }

  /// 암호로 보호된 PDF의 암호를 묻는다. pdfrx는 null(취소)이나 맞는 암호가 나올 때까지 이 함수를 되풀이해서 부른다.
  Future<String?> _askPassword() async {
    if (!mounted) return null;
    return showPasswordDialog(context, fileName: _name, wrong: _passwordAttempts++ > 0);
  }

  Future<void> _loadOutline(PdfDocument document) async {
    try {
      final nodes = await document.loadOutline();
      if (mounted) setState(() => _outline = nodes);
    } on Object {
      // 목차를 못 읽어도 문서는 볼 수 있다
    }
  }

  void _toggleSearch() {
    if (_searcher == null) return; // 문서가 아직 안 열렸다
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) _searcher?.resetTextSearch();
  }

  /// 보기 맞춤: 너비에 맞춤, 쪽에 맞춤, 실제 크기.
  Future<void> _fit(_Fit fit) async {
    if (!_controller.isReady) return;
    final page = _controller.pageNumber ?? 1;
    switch (fit) {
      case _Fit.width:
        final m = _controller.calcMatrixFitWidthForPage(pageNumber: page);
        if (m != null) await _controller.goTo(m);
      case _Fit.page:
        final m = _controller.calcMatrixForFit(pageNumber: page);
        if (m != null) await _controller.goTo(m);
      case _Fit.actual:
        final view = _controller.viewSize;
        final center = _controller.localToDocument(Offset(view.width / 2, view.height / 2));
        await _controller.goTo(_controller.calcMatrixFor(center, zoom: 1.0));
    }
  }

  /// 글자를 고르면(터치는 길게 눌러서) 그 자리에 뜨는 도구줄: 형광펜, 밑줄, 복사, 모두 선택.
  /// pdfrx 기본 도구줄은 Material 문구가 없으면 오류 화면이 뜨고(Android에서 확인), 우리 문구로 쓰고 싶어서 직접 만든다.
  Widget? _selectionMenu(BuildContext context, PdfViewerContextMenuBuilderParams params) {
    if (!params.isTextSelectionEnabled) return null;
    final l10n = AppLocalizations.of(context);
    final delegate = params.textSelectionDelegate;
    final entries = <(String, VoidCallback)>[
      if (delegate.hasSelectedText) ...[
        (l10n.annotTypeHighlight, () => _applyToSelection(underline: false)),
        (l10n.annotTypeUnderline, () => _applyToSelection(underline: true)),
        if (delegate.isCopyAllowed) (l10n.viewerCopy, delegate.copyTextSelection),
      ],
      if (!delegate.isSelectingAllText) (l10n.pagesSelectAll, delegate.selectAllText),
    ];
    if (entries.isEmpty) return null;
    final size = MediaQuery.sizeOf(context);
    final left = (params.anchorA.dx - 110).clamp(8.0, math.max(8.0, size.width - 330)).toDouble();
    return Positioned(
      left: left,
      top: params.anchorA.dy + 14,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, action) in entries)
              TextButton(
                onPressed: () {
                  params.dismissContextMenu();
                  action();
                },
                child: Text(label),
              ),
          ],
        ),
      ),
    );
  }

  /// 그 쪽의 위에 맞춰 이동한다. 기본값은 마지막 쪽만 아래에 맞춰(pdfrx `pageAnchorEnd`) 3쪽짜리 문서의 3쪽을 누르면
  /// 쪽 맨 아래가 보였다. 우리는 항상 쪽의 처음부터 보여 준다.
  Future<void> _goToPage(int pageNumber) => _controller.goToPage(pageNumber: pageNumber, anchor: PdfPageAnchor.top);

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

  /// 메모 도구가 켜진 채 쓰는 도구는 끈다. 메모는 하나씩 입력하는 것이라, 놓고 나면 곧바로 아이콘에 마우스를 올리거나
  /// 눌러 내용을 볼 수 있어야 한다 (도구가 켜져 있으면 입력 층이 아이콘을 덮는다).
  void _endNotePlacement() {
    if (_annotations.tool == DrawTool.note) _annotations.toggleTool(DrawTool.note);
  }

  Future<void> _addNote(int pageIndex, PdfPoint at) async {
    // 기존 메모 아이콘을 누른 것이면 새 메모를 놓는 대신 그 메모를 연다.
    final existing = noteAt(_annotations.items, pageIndex, at);
    if (existing != null) {
      _endNotePlacement();
      await _openNote(existing);
      return;
    }
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
    _endNotePlacement();
    await _add([
      NoteSpec(
        pageIndex: pageIndex,
        color: _annotations.color,
        x: at.x,
        y: (at.y - NoteSpec.iconSize).clamp(0, double.infinity),
        text: text,
        iconSvg: _noteIconSvg,
      ),
    ]);
  }

  bool get _isMac => defaultTargetPlatform == TargetPlatform.macOS;

  /// 마지막으로 한 주석 일을 되돌린다 (⌘Z / Ctrl+Z).
  Future<void> _undo() async {
    final document = _document;
    if (document == null || !_annotations.canUndo || _annotations.busy) return;
    try {
      await _annotations.undo(document);
    } on Object {
      if (mounted) showMessage(context, AppLocalizations.of(context).annotFailed);
    }
  }

  /// 메모를 열어 내용을 읽고, 고치고, 지운다 (쪽의 메모 아이콘이나 주석 목록의 메모 행에서).
  Future<void> _openNote(ReadAnnotation note) async {
    final document = _document;
    if (document == null) return;
    final result = await showNoteDialog(context, initialText: note.contents, pageNumber: note.pageIndex + 1);
    if (result == null || !mounted) return;
    try {
      switch (result.action) {
        case NoteDialogAction.save:
          await _annotations.editNote(document, note, result.text);
        case NoteDialogAction.delete:
          await _annotations.remove(document, note);
      }
    } on Object {
      if (mounted) showMessage(context, AppLocalizations.of(context).annotFailed);
    }
  }

  /// 쪽 위의 메모 아이콘 자리에 얹는 투명한 영역: 마우스를 올리면 내용이 툴팁으로 보이고, 누르면 메모 창이 열린다.
  /// 누르기는 pdfrx가 권하는 [PdfOverlayInteractionRegion]으로 받아 뷰어의 끌기·글자 선택을 방해하지 않는다.
  List<Widget> _noteHotspots(Rect pageRect, PdfPage page) {
    final notes = _annotations.items.where((a) => a.subtype == 1 && a.pageIndex == page.pageNumber - 1);
    return [
      for (final note in notes)
        if (note.rect.right > note.rect.left && note.rect.top > note.rect.bottom)
          Positioned.fromRect(
            rect: PdfRect(
              note.rect.left,
              note.rect.top,
              note.rect.right,
              note.rect.bottom,
            ).toRect(page: page, scaledPageSize: pageRect.size),
            child: _NoteHotspot(note: note, onOpen: () => _openNote(note)),
          ),
    ];
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

  /// 지금 문서(저장 안 한 주석 포함)를 인쇄 설정 창에 넘긴다.
  Future<void> _print() async {
    final document = _document;
    if (document == null || _annotations.busy) return;
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await document.encodePdf();
      if (!mounted) return;
      await showPrintDialog(
        context,
        pdfBytes: bytes,
        pageCount: document.pages.length,
        currentPage: _controller.pageNumber ?? 1,
        jobName: _name,
      );
    } on Object {
      if (mounted) showMessage(context, l10n.printFailed);
    }
  }

  /// 모바일 저장: 경로를 고르는 저장 창(`getSaveLocation`)이 Android에 없어서, 시스템 "문서 만들기" 창에 바이트를 넘겨 사본으로 저장한다.
  Future<bool> _saveMobile(PdfDocument document) async {
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await document.encodePdf();
      final fileName = '${p.basenameWithoutExtension(widget.path)}-annotated.pdf';
      final saved = await FilePicker.saveFile(
        dialogTitle: l10n.annotSave,
        fileName: fileName,
        mimeType: 'application/pdf',
        bytes: bytes,
      );
      if (saved == null || !mounted) return false; // 사용자가 취소했다
      _annotations.markSaved();
      showMessage(context, l10n.pagesSaved(fileName)); // 저장 위치의 이름은 내부 번호라, 제안한 이름을 보여 준다
      return true;
    } on Object {
      if (mounted) showMessage(context, l10n.annotFailed);
      return false;
    }
  }

  /// 주석이 든 PDF를 저장한다. 저장했으면 true.
  Future<bool> _save() async {
    final l10n = AppLocalizations.of(context);
    final document = _document;
    if (document == null) return false;
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      return _saveMobile(document);
    }
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
        child: CallbackShortcuts(
          bindings: {
            SingleActivator(LogicalKeyboardKey.keyZ, meta: _isMac, control: !_isMac): _undo,
            SingleActivator(LogicalKeyboardKey.keyP, meta: _isMac, control: !_isMac): _print,
            SingleActivator(LogicalKeyboardKey.keyF, meta: _isMac, control: !_isMac): _toggleSearch,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                flexibleSpace: const FocusTint(),
                title: Text(_name, overflow: TextOverflow.ellipsis),
                actions: [
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) {
                      if (!_controller.isReady) return const SizedBox.shrink();
                      return StatusPill(label: l10n.viewerPageOf(_controller.pageNumber ?? 1, _controller.pageCount));
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _ZoomButtons(
                    controller: _controller,
                    zoomIn: l10n.viewerZoomIn,
                    zoomOut: l10n.viewerZoomOut,
                    fitLabel: l10n.viewerFit,
                    fitWidth: l10n.viewerFitWidth,
                    fitPage: l10n.viewerFitPage,
                    actualSize: l10n.viewerActualSize,
                    onFit: _fit,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  if (_annotations.dirty) ...[
                    StatusPill(label: l10n.annotUnsavedShort, tone: PillTone.warning),
                    const SizedBox(width: AppSpacing.sm),
                  ],
                  FilledButton.tonalIcon(
                    onPressed: _annotations.busy ? null : _save,
                    icon: const Icon(Icons.save_outlined, size: 18),
                    label: Text(l10n.annotSave),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  IconButton(
                    tooltip: l10n.viewerSearchTip(_isMac ? '⌘F' : 'Ctrl+F'),
                    isSelected: _showSearch,
                    icon: const Icon(Icons.search_rounded),
                    selectedIcon: const Icon(Icons.search_rounded),
                    onPressed: _toggleSearch,
                  ),
                  // 인쇄와 페이지 도구는 데스크톱 기능이다 (폰·태블릿 앱은 읽기와 메모에 집중한다).
                  if (!isMobilePlatform) ...[
                    IconButton(
                      tooltip: l10n.printTip(_isMac ? '⌘P' : 'Ctrl+P'),
                      icon: const Icon(Icons.print_outlined),
                      onPressed: _print,
                    ),
                    IconButton(
                      tooltip: l10n.viewerEditPages,
                      icon: const Icon(Icons.dashboard_customize_outlined),
                      onPressed: () =>
                          Navigator.of(context)
                              .push(MaterialPageRoute<void>(builder: (_) => PageToolsScreen(initialPath: widget.path))),
                    ),
                  ],
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
                  Material(
                    color: Theme.of(context).colorScheme.surface,
                    child: Column(
                      children: [
                        AnnotationToolbar(
                          state: _annotations,
                          onHighlight: () => _applyToSelection(underline: false),
                          onUnderline: () => _applyToSelection(underline: true),
                          showList: _showList,
                          onToggleList: () => setState(() => _showList = !_showList),
                          onUndo: _undo,
                          undoShortcut: _isMac ? '⌘Z' : 'Ctrl+Z',
                        ),
                        const Divider(height: 1),
                        if (_showSearch && _searcher != null)
                          ViewerSearchBar(searcher: _searcher!, onClose: _toggleSearch),
                      ],
                    ),
                  ),
                  Expanded(child: _content(l10n)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 쪽 썸네일 목록. 보기 본문과 같은 문서를 쓴다 (따로 열면 암호 PDF는 암호를 두 번 묻고 주석도 안 보인다).
  Widget _thumbnails() => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) {
      if (!_controller.isReady) return const SizedBox.shrink();
      final document = _controller.document;
      final current = _controller.pageNumber;
      return ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: document.pages.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => _Thumbnail(
          document: document,
          pageNumber: index + 1,
          selected: current == index + 1,
          onTap: () => _goToPage(index + 1),
        ),
      );
    },
  );

  Widget _content(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    final dark = scheme.brightness == Brightness.dark;
    return Row(
      children: [
        if (_showThumbnails)
          Container(
            width: _sidebar == _Sidebar.outline ? 248 : 148,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(right: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              children: [
                if (_outline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
                    child: SegmentedButton<_Sidebar>(
                      showSelectedIcon: false,
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                      segments: [
                        ButtonSegment(value: _Sidebar.pages, label: Text(l10n.sidebarPages)),
                        ButtonSegment(value: _Sidebar.outline, label: Text(l10n.sidebarOutline)),
                      ],
                      selected: {_sidebar},
                      onSelectionChanged: (v) => setState(() => _sidebar = v.first),
                    ),
                  ),
                Expanded(
                  child: _sidebar == _Sidebar.outline && _outline.isNotEmpty
                      ? OutlinePanel(nodes: _outline, onTap: (node) => _controller.goToDest(node.dest))
                      : _thumbnails(),
                ),
              ],
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              PdfViewer.file(
                widget.path,
                controller: _controller,
                passwordProvider: _askPassword,
                params: PdfViewerParams(
                  backgroundColor: dark ? const Color(0xFF0F151C) : const Color(0xFFE8ECF2),
                  margin: 16,
                  pageDropShadow: BoxShadow(
                    color: Colors.black.withValues(alpha: dark ? 0.5 : 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                  // 그리는 도구가 켜져 있으면 끌기는 그리기에 쓰이므로 화면 끌기를 끈다 (휠 스크롤·확대는 그대로).
                  panEnabled: !_annotations.drawing,
                  pageOverlaysBuilder: (context, pageRect, page) => _noteHotspots(pageRect, page),
                  buildContextMenu: _selectionMenu,
                  pagePaintCallbacks: [
                    (canvas, pageRect, page) => _searcher?.pageTextMatchPaintCallback(canvas, pageRect, page),
                  ],
                  onViewerReady: (document, controller) {
                    _searcher ??= PdfTextSearcher(controller);
                    _annotations.refresh(document);
                    _loadOutline(document);
                  },
                  errorBannerBuilder: (context, error, stackTrace, documentRef) => Center(
                    child: Text(error is PdfPasswordException ? l10n.errPasswordProtected(_name) : l10n.openFailed),
                  ),
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
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(left: BorderSide(color: scheme.outlineVariant)),
            ),
            child: AnnotationPanel(
              state: _annotations,
              onJump: _goToPage,
              onOpenNote: (note) {
                _goToPage(note.pageIndex + 1);
                _openNote(note);
              },
              onDelete: _delete,
            ),
          ),
      ],
    );
  }
}

/// 쪽 위 메모 아이콘 자리의 투명한 영역. 마우스를 올리면 내용이 툴팁으로 뜨고, 누르면 [onOpen]이 불린다.
///
/// 이 영역이 뷰어로 가는 입력을 막으면 안 된다(뷰어가 끌기·글자 선택·누르기를 모두 받아야 한다):
/// - 올리기는 `opaque: false`인 [MouseRegion]으로만 받는다 (기본값은 아래 위젯으로 가는 입력을 막는다).
/// - 툴팁은 직접 띄우고 [IgnorePointer]로 감싸 입력을 받지 않게 한다 (Tooltip 안의 영역도 입력을 막는다).
/// - 누르기는 pdfrx가 권하는 [PdfOverlayInteractionRegion]으로 받는다.
class _NoteHotspot extends StatefulWidget {
  const _NoteHotspot({required this.note, required this.onOpen});

  final ReadAnnotation note;
  final VoidCallback onOpen;

  @override
  State<_NoteHotspot> createState() => _NoteHotspotState();
}

class _NoteHotspotState extends State<_NoteHotspot> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _tooltip.currentState?.ensureTooltipVisible(),
      onExit: (_) => Tooltip.dismissAllToolTips(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Tooltip(
              key: _tooltip,
              message: widget.note.contents,
              triggerMode: TooltipTriggerMode.manual,
              constraints: const BoxConstraints(maxWidth: 320),
              child: const SizedBox.expand(),
            ),
          ),
          PdfOverlayInteractionRegion(
            onTap: (_) {
              widget.onOpen();
              return true; // 처리했다는 뜻 (뷰어가 같은 누르기를 다시 쓰지 않는다)
            },
            child: const SizedBox.expand(),
          ),
        ],
      ),
    );
  }
}

/// 사이드바 썸네일: 지금 보는 쪽은 강조 테두리, 아래에 쪽 번호.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.document, required this.pageNumber, required this.selected, required this.onTap});

  final PdfDocument document;
  final int pageNumber;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      radius: AppRadius.button + 4,
      padding: const EdgeInsets.all(AppSpacing.sm),
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 112,
            child: PageThumbnail(document: document, pageNumber: pageNumber),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '$pageNumber',
            style: theme.textTheme.labelMedium?.copyWith(
              color: selected ? theme.colorScheme.primary : null,
              fontWeight: selected ? FontWeight.w800 : null,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Sidebar { pages, outline }

enum _Fit { width, page, actual }

/// 확대/축소 묶음: 알약 하나 안에 단추 둘과 보기 맞춤 메뉴.
class _ZoomButtons extends StatelessWidget {
  const _ZoomButtons({
    required this.controller,
    required this.zoomIn,
    required this.zoomOut,
    required this.fitLabel,
    required this.fitWidth,
    required this.fitPage,
    required this.actualSize,
    required this.onFit,
  });

  final PdfViewerController controller;
  final String zoomIn;
  final String zoomOut;
  final String fitLabel;
  final String fitWidth;
  final String fitPage;
  final String actualSize;
  final void Function(_Fit fit) onFit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: zoomOut,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_rounded),
            onPressed: () => controller.isReady ? controller.zoomDown() : null,
          ),
          IconButton(
            tooltip: zoomIn,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_rounded),
            onPressed: () => controller.isReady ? controller.zoomUp() : null,
          ),
          PopupMenuButton<_Fit>(
            tooltip: fitLabel,
            icon: const Icon(Icons.fit_screen_outlined),
            iconSize: 20,
            padding: EdgeInsets.zero,
            onSelected: onFit,
            itemBuilder: (_) => [
              PopupMenuItem(value: _Fit.width, child: Text(fitWidth)),
              PopupMenuItem(value: _Fit.page, child: Text(fitPage)),
              PopupMenuItem(value: _Fit.actual, child: Text(actualSize)),
            ],
          ),
        ],
      ),
    );
  }
}

enum _Leave { stay, discard, save }
