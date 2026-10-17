import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../convert/conversion_error.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import 'page_ops.dart';
import 'page_ranges.dart';
import 'pdf_dialogs.dart';

enum _Mode { each, everyN, ranges }

/// PDF 하나를 여러 PDF로 나눈다: 한 쪽씩, N쪽마다, 또는 범위(`1-3, 5, 8-`)마다 파일 하나.
class SplitTab extends StatefulWidget {
  const SplitTab({super.key});

  @override
  State<SplitTab> createState() => _SplitTabState();
}

class _SplitTabState extends State<SplitTab> with AutomaticKeepAliveClientMixin {
  String? _path;
  int _pageCount = 0;
  _Mode _mode = _Mode.each;
  final _everyN = TextEditingController(text: '2');
  final _ranges = TextEditingController();
  bool _busy = false;
  bool _dragging = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _everyN.dispose();
    _ranges.dispose();
    super.dispose();
  }

  Future<void> _load(String path) async {
    int? count;
    await runReporting(context, () async => count = await PageOps.pageCount(path));
    if (count == null || !mounted) return;
    setState(() {
      _path = path;
      _pageCount = count!;
    });
  }

  List<List<int>> _groups() => switch (_mode) {
    _Mode.each => splitEveryN(_pageCount, 1),
    _Mode.everyN => splitEveryN(_pageCount, _parseN()),
    _Mode.ranges => parsePageGroups(_ranges.text, _pageCount),
  };

  int _parseN() {
    final n = int.tryParse(_everyN.text.trim());
    if (n == null) throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: _everyN.text.trim());
    return n;
  }

  Future<void> _split() async {
    final l10n = AppLocalizations.of(context);
    final source = _path!;
    final List<List<int>> groups;
    try {
      groups = _groups();
    } on ConversionException catch (e) {
      showMessage(context, l10n.errInvalidRange(e.fileName));
      return;
    }
    final dir = await getDirectoryPath(confirmButtonText: l10n.splitChooseFolder, initialDirectory: p.dirname(source));
    if (dir == null || !mounted) return;
    setState(() => _busy = true);
    var created = 0;
    final ok = await runReporting(context, () async => created = (await PageOps.split(source, dir, groups)).length);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) showMessage(context, l10n.pagesSavedMany(created));
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
        final pdf = details.files.map((f) => f.path).where(isPdf).firstOrNull;
        if (pdf != null) _load(pdf);
      },
      child: Container(
        color: _dragging ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              final path = await pickPdf(l10n);
                              if (path != null && mounted) _load(path);
                            },
                      child: Text(l10n.splitChoose),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    if (_path != null)
                      Expanded(
                        child: Text(
                          '${p.basename(_path!)} · ${l10n.splitPageCount(_pageCount)}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                if (_path != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  SegmentedButton<_Mode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: _Mode.each, label: Text(l10n.splitModeEach)),
                      ButtonSegment(value: _Mode.everyN, label: Text(l10n.splitModeEveryN)),
                      ButtonSegment(value: _Mode.ranges, label: Text(l10n.splitModeRanges)),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (s) => setState(() => _mode = s.first),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (_mode == _Mode.everyN)
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: _everyN,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l10n.splitEveryNLabel),
                      ),
                    ),
                  if (_mode == _Mode.ranges)
                    TextField(
                      controller: _ranges,
                      decoration: InputDecoration(labelText: l10n.splitRangesLabel),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(onPressed: _busy ? null : _split, child: Text(l10n.splitAction)),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.md),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
