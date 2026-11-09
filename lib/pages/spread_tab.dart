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
import 'source_holder.dart';

/// 펼침면 나누기: 한 쪽에 두 면이 나란히 찍힌 스캔본을 가운데에서 잘라 왼쪽·오른쪽 낱쪽으로 만든다.
/// 쪽 범위를 비워 두면 모든 쪽을 나누고, 적으면 그 쪽만 나눈다(표지처럼 한 면인 쪽은 그대로 둔다).
class SpreadTab extends StatefulWidget {
  const SpreadTab({super.key, this.initialPath, this.currentPath, this.holder});

  /// 처음부터 열어 둘 PDF (테스트·화면 확인용).
  final String? initialPath;

  /// 이 화면을 연 보기 화면: 그 파일 위로 저장할 때 저장하는 동안 놓아 달라고 한다.
  final SourceHolder? holder;

  /// 페이지 도구에서 지금 열려 있는 PDF. 이 탭에서 직접 고르기 전에는 이 파일을 기본으로 연다.
  final String? currentPath;

  @override
  State<SpreadTab> createState() => _SpreadTabState();
}

class _SpreadTabState extends State<SpreadTab> with AutomaticKeepAliveClientMixin {
  String? _path;
  int _pageCount = 0;
  bool _rightFirst = false;
  final _ranges = TextEditingController();
  bool _busy = false;

  /// 사용자가 이 탭에서 직접 파일을 골랐는지 (그러면 [SpreadTab.currentPath]가 바뀌어도 따라가지 않는다).
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
  void didUpdateWidget(SpreadTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = widget.currentPath;
    if (!_chosenHere && current != null && current != oldWidget.currentPath && current != _path) {
      _load(current, quiet: true);
    }
  }

  @override
  void dispose() {
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

  /// 나눌 쪽 번호. 범위를 비워 두면 모든 쪽. 잘못된 입력이면 [ConversionException]을 던진다.
  Set<int> _spreadPages() => _ranges.text.trim().isEmpty
      ? {for (var n = 1; n <= _pageCount; n++) n}
      : parsePageList(_ranges.text, _pageCount).toSet();

  Future<void> _save(Set<int> pages) async {
    final l10n = AppLocalizations.of(context);
    final source = _path!;
    final target = await pickPdfSavePath(
      l10n,
      suggestedName: '${p.basenameWithoutExtension(source)}-split.pdf',
      initialDirectory: p.dirname(source),
    );
    if (target == null || !mounted) return;
    final held = await releaseHeldTarget(context, widget.holder, target);
    if (held == null || !mounted) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await runReporting(context, () => PageOps.splitSpreads(source, target, pages, rightFirst: _rightFirst));
    } finally {
      if (held) widget.holder?.reacquire();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) showSaved(context, l10n.pagesSaved(p.basename(target)), path: target, held: held);
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
                Icon(Icons.vertical_split_rounded, size: 44, color: theme.colorScheme.primary),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.spreadDropHint, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.spreadDescription, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
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

    Set<int>? pages;
    String? problem;
    try {
      pages = _spreadPages();
    } on ConversionException catch (e) {
      problem = l10n.errInvalidRange(e.fileName);
    }
    final resultPages = pages == null ? 0 : _pageCount + pages.length;
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
                    Text(l10n.spreadDescription, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _ranges,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(labelText: l10n.spreadRangesLabel, helperText: l10n.spreadRangesHelp),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: false, label: Text(l10n.spreadLeftFirst)),
                        ButtonSegment(value: true, label: Text(l10n.spreadRightFirst)),
                      ],
                      selected: {_rightFirst},
                      onSelectionChanged: (s) => setState(() => _rightFirst = s.first),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        if (pages != null && pages.isNotEmpty)
                          StatusPill(
                            label: l10n.spreadPreview(resultPages),
                            tone: PillTone.info,
                            icon: Icons.vertical_split_rounded,
                          ),
                        if (problem != null)
                          StatusPill(label: problem, tone: PillTone.danger, icon: Icons.error_outline_rounded),
                        const Spacer(),
                        FilledButton(
                          onPressed: _busy || pages == null || pages.isEmpty ? null : () => _save(pages!),
                          child: Text(l10n.spreadAction),
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
