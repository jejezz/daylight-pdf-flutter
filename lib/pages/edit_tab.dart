import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/page_thumbnail.dart';
import '../widgets/status_pill.dart';
import '../widgets/tool_chip.dart';
import 'page_ops.dart';
import 'pdf_dialogs.dart';
import 'reorder.dart';

class _Item {
  _Item(this.index);

  /// 원본 문서에서의 쪽 위치 (0부터).
  final int index;
  int turns = 0;
  bool selected = false;
}

/// 쪽 편집: 썸네일 격자에서 눌러 고르고, 끌어서 순서를 바꾸고, 회전·삭제·선택한 쪽만 저장.
/// 원본 파일은 저장 전까지 바뀌지 않는다.
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
    if (_selected.isEmpty) {
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

  Future<void> _pick() async {
    final path = await pickPdf(AppLocalizations.of(context));
    if (path != null && mounted) _load(path);
  }

  void _dropped(List<String> paths) {
    final pdf = paths.where(isPdf).firstOrNull;
    if (pdf != null) _load(pdf);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final document = _document;
    if (document == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: DropZone(
          onDrop: _dropped,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.dashboard_customize_outlined, size: 44, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.pagesEmpty, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(l10n.pagesOpenPdf),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        _toolbar(l10n),
        Expanded(
          child: DropArea(
            onDrop: _dropped,
            child: Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Wrap(
                      spacing: AppSpacing.lg,
                      runSpacing: AppSpacing.lg,
                      children: [
                        for (var position = 0; position < _items.length; position++) _slot(document, position),
                        if (_dragging) _endTarget(l10n),
                      ],
                    ),
                  ),
                ),
                if (_busy) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _toolbar(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final selectedCount = _selected.length;
    return Material(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 1100;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    ToolChip(
                      icon: Icons.folder_open_rounded,
                      label: l10n.pagesOpenPdf,
                      compact: compact,
                      onPressed: _busy ? null : _pick,
                    ),
                    const _Divider(),
                    ToolChip(
                      icon: selectedCount == _items.length && _items.isNotEmpty ? Icons.deselect : Icons.select_all,
                      label: l10n.pagesSelectAll,
                      compact: compact,
                      onPressed: () {
                        final all = selectedCount != _items.length;
                        setState(() {
                          for (final i in _items) {
                            i.selected = all;
                          }
                        });
                      },
                    ),
                    ToolChip(
                      icon: Icons.rotate_left_rounded,
                      label: l10n.pagesRotateLeft,
                      compact: compact,
                      onPressed: () => _rotateSelected(3),
                    ),
                    ToolChip(
                      icon: Icons.rotate_right_rounded,
                      label: l10n.pagesRotateRight,
                      compact: compact,
                      onPressed: () => _rotateSelected(1),
                    ),
                    ToolChip(
                      icon: Icons.delete_outline_rounded,
                      label: l10n.pagesDelete,
                      compact: compact,
                      danger: true,
                      onPressed: _deleteSelected,
                    ),
                    ToolChip(
                      icon: Icons.restart_alt_rounded,
                      label: l10n.pagesReset,
                      compact: compact,
                      onPressed: _reset,
                    ),
                    const Spacer(),
                    StatusPill(label: l10n.pagesPageLabel(_items.length)),
                    if (selectedCount > 0) ...[
                      const SizedBox(width: AppSpacing.sm),
                      StatusPill(label: l10n.pagesSelectedCount(selectedCount), tone: PillTone.info),
                    ],
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton(
                      onPressed: _busy ? null : () => _save(selectedOnly: true),
                      child: Text(l10n.pagesExtract),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    FilledButton(
                      onPressed: _busy ? null : () => _save(selectedOnly: false),
                      child: Text(l10n.pagesSave),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  /// 격자의 한 칸: 끌 수 있고, 다른 칸 위에 놓으면 그 칸 앞으로 끼어든다.
  Widget _slot(PdfDocument document, int position) {
    final item = _items[position];
    final rotation = PdfPageRotation.values[(document.pages[item.index].rotation.index + item.turns) & 3];
    PageTile tile({bool dropCue = false}) => PageTile(
      document: document,
      pageNumber: item.index + 1,
      position: position + 1,
      rotation: rotation,
      turns: item.turns,
      selected: item.selected,
      dropCue: dropCue,
      moved: position != item.index,
      onTap: () => setState(() => item.selected = !item.selected),
    );
    return DragTarget<int>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => setState(() {
        _items = moveBefore(_items, details.data, position);
        _dragging = false;
      }),
      builder: (context, candidates, _) => Draggable<int>(
        data: position,
        onDragStarted: () => setState(() => _dragging = true),
        onDragEnd: (_) => setState(() => _dragging = false),
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(opacity: 0.9, child: tile()),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: tile()),
        child: tile(dropCue: candidates.isNotEmpty),
      ),
    );
  }

  /// 끄는 동안만 보이는 "맨 뒤" 놓는 자리.
  Widget _endTarget(AppLocalizations l10n) => DragTarget<int>(
    onWillAcceptWithDetails: (_) => true,
    onAcceptWithDetails: (details) => setState(() {
      _items = moveBefore(_items, details.data, _items.length);
      _dragging = false;
    }),
    builder: (context, candidates, _) {
      final active = candidates.isNotEmpty;
      final scheme = Theme.of(context).colorScheme;
      return Container(
        width: PageTile.width,
        height: PageTile.height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? scheme.primary.withValues(alpha: 0.1) : null,
          borderRadius: BorderRadius.circular(AppRadius.tile),
          border: Border.all(color: active ? scheme.primary : scheme.outline, width: active ? 2 : 1),
        ),
        child: Text(l10n.pagesMoveToEnd, style: Theme.of(context).textTheme.labelMedium),
      );
    },
  );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    child: SizedBox(height: 22, child: VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant)),
  );
}

/// 쪽 하나를 보여 주는 카드: 썸네일, 현재 위치 번호, 회전 표시, 선택 표시.
/// 끌어서 놓을 위치에 들어오면 [dropCue]로 왼쪽에 끼어들 자리를 보여 준다.
class PageTile extends StatelessWidget {
  const PageTile({
    super.key,
    required this.document,
    required this.pageNumber,
    required this.position,
    required this.rotation,
    required this.turns,
    required this.selected,
    required this.onTap,
    this.dropCue = false,
    this.moved = false,
  });

  static const width = 156.0;
  static const height = 232.0;

  final PdfDocument document;

  /// 원본 문서에서의 쪽 번호 (1부터).
  final int pageNumber;

  /// 지금 목록에서의 위치 (1부터).
  final int position;
  final PdfPageRotation rotation;
  final int turns;
  final bool selected;
  final bool dropCue;

  /// 원래 자리에서 옮겨졌는지 (원본 번호를 보조 글자로 보여 준다).
  final bool moved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GlassCard(
              radius: AppRadius.tile,
              padding: const EdgeInsets.all(AppSpacing.sm),
              selected: selected,
              onTap: onTap,
              child: Column(
                children: [
                  Expanded(
                    child: PageThumbnail(
                      key: ValueKey('$pageNumber-$turns'),
                      document: document,
                      pageNumber: pageNumber,
                      rotation: rotation,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Text(l10n.pagesPageLabel(position), style: theme.textTheme.titleSmall),
                      if (moved) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Text('#$pageNumber', style: theme.textTheme.bodySmall),
                      ],
                      const Spacer(),
                      if (turns != 0) StatusPill(label: '${turns * 90}°', icon: Icons.rotate_right_rounded),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            top: AppSpacing.md,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? theme.colorScheme.primary : Colors.white.withValues(alpha: 0.85),
                border: Border.all(color: selected ? theme.colorScheme.primary : theme.colorScheme.outline, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
          ),
          if (dropCue)
            Positioned(
              left: -AppSpacing.md,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    );
  }
}
