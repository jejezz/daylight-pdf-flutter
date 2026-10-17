import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/tool_chip.dart';
import 'page_ops.dart';
import 'pdf_dialogs.dart';

/// 여러 PDF를 목록 순서대로 하나로 합친다. 목록은 끌어서 순서를 바꾼다.
class MergeTab extends StatefulWidget {
  const MergeTab({super.key, this.initialFiles = const [], this.countPages = PageOps.pageCount});

  /// 처음부터 목록에 넣어 둘 PDF (테스트·화면 확인용).
  final List<String> initialFiles;

  /// 쪽 수를 세는 함수. 테스트에서 바꿔 끼워 호출 횟수를 확인한다.
  final Future<int> Function(String path) countPages;

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> with AutomaticKeepAliveClientMixin {
  late final _files = <String>[...widget.initialFiles];
  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  void _add(Iterable<String> paths) => setState(() => _files.addAll(paths.where(isPdf)));

  Future<void> _pick() async {
    final paths = await pickPdfs(AppLocalizations.of(context));
    if (mounted) _add(paths);
  }

  Future<void> _merge() async {
    final l10n = AppLocalizations.of(context);
    if (_files.length < 2) {
      showMessage(context, l10n.mergeNeedTwo);
      return;
    }
    final target = await pickPdfSavePath(l10n, suggestedName: 'merged.pdf', initialDirectory: p.dirname(_files.first));
    if (target == null || !mounted) return;
    setState(() => _busy = true);
    final ok = await runReporting(context, () => PageOps.merge(List.of(_files), target));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) showMessage(context, l10n.pagesSaved(p.basename(target)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    if (_files.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: DropZone(
          onDrop: _add,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.library_add_outlined, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.mergeEmpty, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.mergeDropHint, style: theme.textTheme.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l10n.mergeAdd),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return DropArea(
      onDrop: _add,
      child: Column(
        children: [
          Material(
            color: theme.colorScheme.surface,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      ToolChip(icon: Icons.add_rounded, label: l10n.mergeAdd, onPressed: _busy ? null : _pick),
                      const Spacer(),
                      StatusPill(label: '${_files.length}'),
                      const SizedBox(width: AppSpacing.md),
                      FilledButton(
                        onPressed: _busy || _files.length < 2 ? null : _merge,
                        child: Text(l10n.mergeAction),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      buildDefaultDragHandles: false,
                      itemCount: _files.length,
                      proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
                      onReorderItem: (from, to) => setState(() => _files.insert(to, _files.removeAt(from))),
                      itemBuilder: (context, i) => Padding(
                        key: ValueKey('${_files[i]}#$i'),
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _FileRow(
                          index: i,
                          path: _files[i],
                          countPages: widget.countPages,
                          onRemove: () => setState(() => _files.removeAt(i)),
                          removeTooltip: l10n.mergeRemove,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_busy) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.index,
    required this.path,
    required this.countPages,
    required this.onRemove,
    required this.removeTooltip,
  });

  final int index;
  final String path;
  final Future<int> Function(String path) countPages;
  final VoidCallback onRemove;
  final String removeTooltip;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  /// 쪽 수는 한 번만 센다. FutureBuilder에 build마다 새 future를 주면, 결과가 도착해 다시 그릴 때마다 파일을 또 열게 된다.
  late final Future<int> _pageCount = widget.countPages(widget.path);

  @override
  Widget build(BuildContext context) {
    final index = widget.index, path = widget.path;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return GlassCard(
      radius: AppRadius.tile,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: MouseRegion(
              cursor: SystemMouseCursors.grab,
              child: Icon(Icons.drag_indicator_rounded, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(Icons.picture_as_pdf_rounded, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.basename(path), overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                Text(p.dirname(path), overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          FutureBuilder<int>(
            future: _pageCount,
            builder: (context, snapshot) => snapshot.hasError
                ? StatusPill(label: l10n.errCannotRead(''), tone: PillTone.danger)
                : snapshot.hasData
                ? StatusPill(label: l10n.pagesPageLabel(snapshot.data!))
                : const SizedBox.shrink(),
          ),
          IconButton(tooltip: widget.removeTooltip, icon: const Icon(Icons.close_rounded), onPressed: widget.onRemove),
        ],
      ),
    );
  }
}
