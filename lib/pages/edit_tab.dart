import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'page_ops.dart';
import 'pdf_dialogs.dart';

class _Item {
  _Item(this.index);

  /// 원본 문서에서의 쪽 위치 (0부터).
  final int index;
  int turns = 0;
  bool selected = false;
}

/// 쪽 편집: 끌어서 순서 바꾸기, 회전, 삭제, 선택한 쪽만 저장. 원본 파일은 저장 전까지 바뀌지 않는다.
class EditTab extends StatefulWidget {
  const EditTab({super.key, this.initialPath});

  final String? initialPath;

  @override
  State<EditTab> createState() => _EditTabState();
}

class _EditTabState extends State<EditTab> with AutomaticKeepAliveClientMixin {
  String? _path;
  PdfDocument? _document;
  List<_Item> _items = [];
  bool _busy = false;
  bool _dragging = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPath;
    if (initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _load(initial));
  }

  @override
  void dispose() {
    _document?.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    final l10n = AppLocalizations.of(context);
    final name = p.basename(path);
    final PdfDocument opened;
    try {
      opened = await PdfDocument.openFile(path, passwordProvider: () => null);
    } on PdfPasswordException {
      if (mounted) showMessage(context, l10n.errPasswordProtected(name));
      return;
    } catch (_) {
      if (mounted) showMessage(context, l10n.errCannotRead(name));
      return;
    }
    if (!mounted) {
      opened.dispose();
      return;
    }
    _document?.dispose();
    setState(() {
      _path = path;
      _document = opened;
      _items = [for (var i = 0; i < opened.pages.length; i++) _Item(i)];
    });
  }

  List<_Item> get _selected => _items.where((i) => i.selected).toList();

  void _rotateSelected(int delta) {
    final selected = _selected;
    if (selected.isEmpty) {
      showMessage(context, AppLocalizations.of(context).pagesNothingSelected);
      return;
    }
    setState(() {
      for (final item in selected) {
        item.turns = (item.turns + delta) & 3;
      }
    });
  }

  void _deleteSelected() {
    final selected = _selected;
    if (selected.isEmpty) {
      showMessage(context, AppLocalizations.of(context).pagesNothingSelected);
      return;
    }
    setState(() => _items = _items.where((i) => !i.selected).toList());
  }

  void _reset() => setState(() => _items = [for (var i = 0; i < _document!.pages.length; i++) _Item(i)]);

  Future<void> _save({required bool selectedOnly}) async {
    final l10n = AppLocalizations.of(context);
    final source = _path!;
    final chosen = selectedOnly ? _selected : _items;
    if (selectedOnly && chosen.isEmpty) {
      showMessage(context, l10n.pagesNothingSelected);
      return;
    }
    if (chosen.isEmpty) {
      showMessage(context, l10n.pagesNoneLeft);
      return;
    }
    final base = p.basenameWithoutExtension(source);
    final target = await pickPdfSavePath(
      l10n,
      suggestedName: '$base-${selectedOnly ? 'pages' : 'edited'}.pdf',
      initialDirectory: p.dirname(source),
    );
    if (target == null || !mounted) return;

    final refs = [for (final i in chosen) PageRef(source, i.index, quarterTurns: i.turns)];
    final overwritesSource = p.equals(target, source);
    setState(() => _busy = true);
    if (overwritesSource) {
      // 열려 있는 문서를 먼저 닫아 둔다 (Windows에서 열린 파일은 덮어쓸 수 없다).
      _document?.dispose();
      _document = null;
    }
    final ok = await runReporting(context, () => PageOps.build(refs, target));
    if (!mounted) return;
    if (overwritesSource) {
      await _load(source);
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) showMessage(context, l10n.pagesSaved(p.basename(target)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final document = _document;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final pdf = details.files.map((f) => f.path).where(isPdf).firstOrNull;
        if (pdf != null) _load(pdf);
      },
      child: Container(
        color: _dragging ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
        child: Column(
          children: [
            _toolbar(l10n, document != null),
            const Divider(height: 1),
            Expanded(
              child: document == null
                  ? Center(child: Text(l10n.pagesEmpty, style: Theme.of(context).textTheme.titleMedium))
                  : _pageList(l10n, document),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _toolbar(AppLocalizations l10n, bool hasDocument) {
    final selectedCount = _selected.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    final path = await pickPdf(l10n);
                    if (path != null && mounted) _load(path);
                  },
            child: Text(l10n.pagesOpenPdf),
          ),
          if (hasDocument) ...[
            IconButton(
              tooltip: l10n.pagesSelectAll,
              icon: Icon(selectedCount == _items.length && _items.isNotEmpty ? Icons.deselect : Icons.select_all),
              onPressed: () {
                final all = selectedCount != _items.length;
                setState(() {
                  for (final i in _items) {
                    i.selected = all;
                  }
                });
              },
            ),
            IconButton(
              tooltip: l10n.pagesRotateLeft,
              icon: const Icon(Icons.rotate_left_rounded),
              onPressed: () => _rotateSelected(3),
            ),
            IconButton(
              tooltip: l10n.pagesRotateRight,
              icon: const Icon(Icons.rotate_right_rounded),
              onPressed: () => _rotateSelected(1),
            ),
            IconButton(
              tooltip: l10n.pagesDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _deleteSelected,
            ),
            IconButton(tooltip: l10n.pagesReset, icon: const Icon(Icons.restart_alt_rounded), onPressed: _reset),
            if (selectedCount > 0) Text(l10n.pagesSelectedCount(selectedCount)),
            OutlinedButton(onPressed: _busy ? null : () => _save(selectedOnly: true), child: Text(l10n.pagesExtract)),
            FilledButton(onPressed: _busy ? null : () => _save(selectedOnly: false), child: Text(l10n.pagesSave)),
          ],
        ],
      ),
    );
  }

  Widget _pageList(AppLocalizations l10n, PdfDocument document) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      itemCount: _items.length,
      onReorderItem: (from, to) => setState(() {
        _items.insert(to, _items.removeAt(from));
      }),
      itemBuilder: (context, position) {
        final item = _items[position];
        final original = document.pages[item.index].rotation;
        final rotation = PdfPageRotation.values[(original.index + item.turns) & 3];
        return Card(
          key: ValueKey(item),
          child: CheckboxListTile(
            value: item.selected,
            onChanged: (v) => setState(() => item.selected = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            secondary: SizedBox(
              width: 120,
              height: 100,
              child: PdfPageView(
                key: ValueKey('${item.index}-${item.turns}'),
                document: document,
                pageNumber: item.index + 1,
                rotationOverride: rotation,
              ),
            ),
            title: Text(l10n.pagesPageLabel(position + 1)),
            subtitle: position + 1 == item.index + 1 ? null : Text('#${item.index + 1}'),
          ),
        );
      },
    );
  }
}
