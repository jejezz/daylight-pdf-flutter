import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'page_ops.dart';
import 'pdf_dialogs.dart';

/// 여러 PDF를 목록 순서대로 하나로 합친다. 목록은 끌어서 순서를 바꾼다.
class MergeTab extends StatefulWidget {
  const MergeTab({super.key});

  @override
  State<MergeTab> createState() => _MergeTabState();
}

class _MergeTabState extends State<MergeTab> with AutomaticKeepAliveClientMixin {
  final _files = <String>[];
  bool _busy = false;
  bool _dragging = false;

  @override
  bool get wantKeepAlive => true;

  void _add(Iterable<String> paths) => setState(() => _files.addAll(paths.where(isPdf)));

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
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        _add(details.files.map((f) => f.path));
      },
      child: Container(
        color: _dragging ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              child: Row(
                children: [
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            final paths = await pickPdfs(l10n);
                            if (mounted) _add(paths);
                          },
                    child: Text(l10n.mergeAdd),
                  ),
                  const Spacer(),
                  FilledButton(onPressed: _busy || _files.length < 2 ? null : _merge, child: Text(l10n.mergeAction)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _files.isEmpty
                  ? Center(child: Text(l10n.mergeEmpty, style: theme.textTheme.titleMedium))
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      itemCount: _files.length,
                      onReorderItem: (from, to) => setState(() {
                        _files.insert(to, _files.removeAt(from));
                      }),
                      itemBuilder: (context, i) => ListTile(
                        key: ValueKey('${_files[i]}#$i'),
                        leading: const Icon(Icons.picture_as_pdf_rounded),
                        title: Text(p.basename(_files[i]), overflow: TextOverflow.ellipsis),
                        subtitle: Text(p.dirname(_files[i]), overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          tooltip: l10n.mergeRemove,
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() => _files.removeAt(i)),
                        ),
                      ),
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
