import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../convert/conversion_error.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_pill.dart';
import 'page_ops.dart';
import 'page_ranges.dart';
import 'pdf_dialogs.dart';

enum _Mode { each, everyN, ranges }

/// PDF 하나를 여러 PDF로 나눈다: 한 쪽씩, N쪽마다, 또는 범위(`1-3, 5, 8-`)마다 파일 하나.
/// 입력하는 동안 "파일 몇 개로 나뉘는지"를 바로 보여 주고, 잘못된 입력은 그 자리에서 알려 준다.
class SplitTab extends StatefulWidget {
  const SplitTab({super.key, this.initialPath});

  /// 처음부터 열어 둘 PDF (테스트·화면 확인용).
  final String? initialPath;

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

  Future<void> _pick() async {
    final path = await pickPdf(AppLocalizations.of(context));
    if (path != null && mounted) _load(path);
  }

  void _dropped(List<String> paths) {
    final pdf = paths.where(isPdf).firstOrNull;
    if (pdf != null) _load(pdf);
  }

  /// 지금 입력으로 나뉘는 묶음. 잘못된 입력이면 [ConversionException]을 던진다.
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

  Future<void> _split(List<List<int>> groups) async {
    final l10n = AppLocalizations.of(context);
    final source = _path!;
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
    final path = _path;
    if (path == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: DropZone(
          onDrop: _dropped,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.call_split_rounded, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.splitDropHint, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: _pick,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(l10n.splitChoose),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 입력을 검사해서 미리보기(파일 수) 또는 오류를 만든다.
    List<List<int>>? groups;
    String? problem;
    try {
      groups = _groups();
    } on ConversionException catch (e) {
      problem = _ranges.text.trim().isEmpty && _mode == _Mode.ranges ? null : l10n.errInvalidRange(e.fileName);
    }
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropZone(
                onDrop: _dropped,
                radius: AppRadius.tile,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(p.basename(path), overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                    ),
                    StatusPill(label: l10n.splitPageCount(_pageCount)),
                    const SizedBox(width: AppSpacing.md),
                    OutlinedButton(onPressed: _busy ? null : _pick, child: Text(l10n.splitChange)),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                    if (_mode == _Mode.everyN) ...[
                      const SizedBox(height: AppSpacing.lg),
                      SizedBox(
                        width: 160,
                        child: TextField(
                          controller: _everyN,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(labelText: l10n.splitEveryNLabel),
                        ),
                      ),
                    ],
                    if (_mode == _Mode.ranges) ...[
                      const SizedBox(height: AppSpacing.lg),
                      TextField(
                        controller: _ranges,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(labelText: l10n.splitRangesLabel),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (groups != null && groups.isNotEmpty)
                          StatusPill(
                            label: l10n.splitPreview(groups.length),
                            tone: PillTone.info,
                            icon: Icons.call_split_rounded,
                          ),
                        if (problem != null)
                          StatusPill(label: problem, tone: PillTone.danger, icon: Icons.error_outline_rounded),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy || groups == null || groups.isEmpty ? null : () => _split(groups!),
                          child: Text(l10n.splitAction),
                        ),
                      ],
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: AppSpacing.md),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
