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
  const SplitTab({super.key, this.initialPath, this.currentPath});

  /// 처음부터 열어 둘 PDF (테스트·화면 확인용).
  final String? initialPath;

  /// 페이지 도구에서 지금 열려 있는 PDF. 이 탭에서 직접 고르기 전에는 이 파일을 기본으로 연다.
  final String? currentPath;

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

  /// 사용자가 이 탭에서 직접 파일을 골랐는지 (그러면 [SplitTab.currentPath]가 바뀌어도 따라가지 않는다).
  bool _chosenHere = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPath ?? widget.currentPath;
    if (initial != null) WidgetsBinding.instance.addPostFrameCallback((_) => _load(initial, quiet: widget.initialPath == null));
  }

  @override
  void didUpdateWidget(SplitTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.currentPath;
    if (!_chosenHere && current != null && current != oldWidget.currentPath && current != _path) {
      _load(current, quiet: true);
    }
  }

  @override
  void dispose() {
    _everyN.dispose();
    _ranges.dispose();
    super.dispose();
  }

  /// [quiet]면 읽지 못해도 알리지 않는다 (다른 탭이 이미 알렸고, 사용자가 이 탭을 고른 것도 아니다).
  Future<void> _load(String path, {bool quiet = false}) async {
    int? count;
    if (quiet) {
      try {
        count = await PageOps.pageCount(path);
      } on ConversionException {
        return;
      }
    } else {
      await runReporting(context, () async => count = await PageOps.pageCount(path));
    }
    if (count == null || !mounted) return;
    setState(() {
      _path = path;
      _pageCount = count!;
    });
  }

  Future<void> _pick() async {
    final path = await pickPdf(AppLocalizations.of(context));
    if (path != null && mounted) _chooseHere(path);
  }

  void _chooseHere(String path) {
    _chosenHere = true;
    _load(path);
  }

  void _dropped(List<String> paths) {
    final pdf = paths.where(isPdf).firstOrNull;
    if (pdf != null) _chooseHere(pdf);
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
    var created = <String>[];
    final ok = await runReporting(context, () async => created = await PageOps.split(source, dir, groups));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok && created.isNotEmpty) {
      showSavedMessage(context, l10n.pagesSavedMany(created.length), path: created.first, actionLabel: l10n.savedOpenFirst);
    }
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
