import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdfrx/pdfrx.dart';
import 'package:printing/printing.dart';

import '../convert/conversion_error.dart';
import '../convert/error_text.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_pill.dart';
import 'print_options.dart';
import 'print_processor.dart';

/// 미리보기는 부담을 줄이려고 앞의 이만큼만 만든다.
const printPreviewLimit = 12;

/// 용지 크기(세로 방향, pt).
const printPapers = <String, (double, double)>{
  'A4': (595.28, 841.89),
  'Letter': (612, 792),
  'Legal': (612, 1008),
  'A3': (841.89, 1190.55),
  'A5': (419.53, 595.28),
};

/// 인쇄 설정 창: 왼쪽에서 설정을 고르고 오른쪽에서 가공된 결과를 미리 본다. "인쇄 창 열기"를 누르면 운영체제 인쇄 창이 뜬다.
/// [pdfBytes]는 지금 열린 문서(저장 안 한 주석 포함), [currentPage]는 보고 있는 쪽(1부터).
Future<void> showPrintDialog(
  BuildContext context, {
  required Uint8List pdfBytes,
  required int pageCount,
  required int currentPage,
  required String jobName,
}) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    insetPadding: const EdgeInsets.all(AppSpacing.xl),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 980, maxHeight: 680),
      child: PrintDialog(pdfBytes: pdfBytes, pageCount: pageCount, currentPage: currentPage, jobName: jobName),
    ),
  ),
);

enum _RangeMode { all, current, custom }

/// 운영체제 인쇄 창이 알려 주는 용지 크기를 가공 설정에 맞춘다. 방향 자동이면 세로 기준으로 바로잡는다.
PrintOptions optionsForFormat(PrintOptions options, double width, double height) => options.autoOrientation
    ? options.copyWith(paperWidth: math.min(width, height), paperHeight: math.max(width, height))
    : options.copyWith(paperWidth: width, paperHeight: height);

class PrintDialog extends StatefulWidget {
  const PrintDialog({
    super.key,
    required this.pdfBytes,
    required this.pageCount,
    required this.currentPage,
    required this.jobName,
    this.openSystemPrint = _openSystemPrint,
  });

  final Uint8List pdfBytes;
  final int pageCount;
  final int currentPage;
  final String jobName;

  /// 가공된 PDF를 운영체제 인쇄 창으로 넘기는 함수. 인쇄(또는 PDF 저장)가 됐으면 true, 사용자가 취소했으면 false.
  /// 시험에서 바꿔 끼운다.
  final Future<bool> Function(PrintOptions options, Uint8List pdfBytes, int currentPage, String jobName)
  openSystemPrint;

  static Future<bool> _openSystemPrint(
    PrintOptions options,
    Uint8List pdfBytes,
    int currentPage,
    String jobName,
  ) {
    return Printing.layoutPdf(
      name: jobName,
      format: PdfPageFormat(options.paperWidth, options.paperHeight),
      // 운영체제 창에서 용지를 바꾸면 그 크기로 다시 가공한다.
      onLayout: (format) => PrintProcessor.build(
        pdfBytes,
        optionsForFormat(options, format.width, format.height),
        currentPage: currentPage,
      ),
    );
  }

  @override
  State<PrintDialog> createState() => _PrintDialogState();
}

class _PrintDialogState extends State<PrintDialog> {
  PrintOptions _options = const PrintOptions();
  _RangeMode _rangeMode = _RangeMode.all;
  final _rangeText = TextEditingController();
  String _paper = 'A4';

  Timer? _debounce;
  int _generation = 0;
  Uint8List? _preview;
  int _previewId = 0; // 미리보기가 바뀔 때마다 새 뷰어를 쓴다 (쓰던 뷰어의 문서를 바꾸면 pdfrx가 배치 도중 오류를 낸다)
  Object? _error;
  bool _working = false;
  int? _selectedCount;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _schedule(immediate: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _rangeText.dispose();
    super.dispose();
  }

  PrintOptions get _effective => _options.copyWith(
    range: switch (_rangeMode) {
      _RangeMode.all => '',
      _RangeMode.current => 'current',
      _RangeMode.custom => _rangeText.text,
    },
  );

  void _change(PrintOptions Function(PrintOptions) edit) {
    setState(() => _options = edit(_options));
    _schedule();
  }

  void _schedule({bool immediate = false}) {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() => _working = true);
    _debounce = Timer(immediate ? Duration.zero : const Duration(milliseconds: 300), () => _render(generation));
  }

  Future<void> _render(int generation) async {
    final options = _effective;
    try {
      final count = selectPrintPages(widget.pageCount, options, currentPage: widget.currentPage).length;
      final bytes = await PrintProcessor.build(
        widget.pdfBytes,
        options,
        currentPage: widget.currentPage,
        limit: printPreviewLimit,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _preview = bytes;
        _previewId++;
        _selectedCount = count;
        _error = null;
        _working = false;
      });
    } on Object catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e;
        _selectedCount = null;
        _working = false;
      });
    }
  }

  Future<void> _print() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _opening = true);
    try {
      final done = await widget.openSystemPrint(_effective, widget.pdfBytes, widget.currentPage, widget.jobName);
      if (!mounted) return;
      // 운영체제 창에서 취소했으면 설정 창은 그대로 둔다 (설정을 고쳐 다시 시도할 수 있게).
      if (done) {
        Navigator.of(context).pop();
      } else {
        setState(() => _opening = false);
      }
    } on Object {
      if (mounted) {
        setState(() => _opening = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.printFailed)));
      }
    }
  }

  String _errorText(AppLocalizations l10n) {
    final e = _error;
    return e is ConversionException ? conversionErrorText(l10n, e) : l10n.printFailed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canPrint = !_opening && _error == null && !_working && _selectedCount != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.print_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.printTitle, style: theme.textTheme.titleLarge),
              const Spacer(),
              if (_selectedCount != null) StatusPill(label: l10n.printPageCount(_selectedCount!)),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: 340, child: _controls(l10n, theme)),
              const VerticalDivider(width: 1),
              Expanded(child: _previewPane(l10n, theme)),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Expanded(child: Text(l10n.printNextStep, style: theme.textTheme.bodySmall)),
              const SizedBox(width: AppSpacing.md),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
              const SizedBox(width: AppSpacing.sm),
              FilledButton.icon(
                onPressed: canPrint ? _print : null,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(l10n.printContinue),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String title, Widget child) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    ),
  );

  Widget _controls(AppLocalizations l10n, ThemeData theme) {
    final invalidRange = _error is ConversionException;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _section(
          l10n.printRange,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<_RangeMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: _RangeMode.all, label: Text(l10n.printRangeAll)),
                  ButtonSegment(value: _RangeMode.current, label: Text(l10n.printRangeCurrent)),
                  ButtonSegment(value: _RangeMode.custom, label: Text(l10n.printRangeCustom)),
                ],
                selected: {_rangeMode},
                onSelectionChanged: (s) {
                  setState(() => _rangeMode = s.first);
                  _schedule();
                },
              ),
              if (_rangeMode == _RangeMode.custom) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _rangeText,
                  autofocus: true,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l10n.printRangeHint,
                    errorText: invalidRange ? _errorText(l10n) : null,
                  ),
                  onChanged: (_) => _schedule(),
                ),
              ],
            ],
          ),
        ),
        _section(
          l10n.printParity,
          SegmentedButton<PrintParity>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: PrintParity.all, label: Text(l10n.printParityAll)),
              ButtonSegment(value: PrintParity.odd, label: Text(l10n.printParityOdd)),
              ButtonSegment(value: PrintParity.even, label: Text(l10n.printParityEven)),
            ],
            selected: {_options.parity},
            onSelectionChanged: (s) => _change((o) => o.copyWith(parity: s.first)),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.printReverse),
          value: _options.reverse,
          onChanged: (v) => _change((o) => o.copyWith(reverse: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.printAnnotations),
          value: _options.includeAnnotations,
          onChanged: (v) => _change((o) => o.copyWith(includeAnnotations: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        _section(
          l10n.printScale,
          SegmentedButton<PrintScale>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: PrintScale.fit, label: Text(l10n.printScaleFit)),
              ButtonSegment(value: PrintScale.shrink, label: Text(l10n.printScaleShrink)),
              ButtonSegment(value: PrintScale.actual, label: Text(l10n.printScaleActual)),
            ],
            selected: {_options.scale},
            onSelectionChanged: (s) => _change((o) => o.copyWith(scale: s.first)),
          ),
        ),
        _section(
          l10n.printMargin,
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final mm in const [0.0, 5.0, 10.0, 15.0, 20.0])
                ChoiceChip(
                  label: Text(mm == 0 ? l10n.printMarginNone : '${mm.toInt()} mm'),
                  selected: _options.marginMm == mm,
                  onSelected: (_) => _change((o) => o.copyWith(marginMm: mm)),
                ),
            ],
          ),
        ),
        _section(
          l10n.printPaper,
          DropdownButton<String>(
            value: _paper,
            isDense: true,
            items: [for (final name in printPapers.keys) DropdownMenuItem(value: name, child: Text(name))],
            onChanged: (name) {
              if (name == null) return;
              final size = printPapers[name]!;
              setState(() => _paper = name);
              _change((o) => o.copyWith(paperWidth: size.$1, paperHeight: size.$2));
            },
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(l10n.printAutoOrientation),
          value: _options.autoOrientation,
          onChanged: (v) => _change((o) => o.copyWith(autoOrientation: v)),
        ),
      ],
    );
  }

  Widget _previewPane(AppLocalizations l10n, ThemeData theme) {
    final bytes = _preview;
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Stack(
        children: [
          if (bytes != null && _error == null)
            Positioned.fill(
              child: PdfViewer.data(
                bytes,
                key: ValueKey(_previewId),
                sourceName: 'print-preview-$_previewId',
                params: PdfViewerParams(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  margin: 16,
                  pageDropShadow: BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                  textSelectionParams: const PdfTextSelectionParams(enabled: false),
                ),
              ),
            ),
          if (_working) const Positioned(left: 0, right: 0, top: 0, child: LinearProgressIndicator()),
          if (bytes == null && _error == null) Center(child: Text(l10n.printPreviewing)),
          if (_error != null)
            Center(
              child: Text(_errorText(l10n), style: TextStyle(color: theme.colorScheme.error)),
            ),
          if (_selectedCount != null && _selectedCount! > printPreviewLimit)
            Positioned(
              left: AppSpacing.md,
              bottom: AppSpacing.md,
              child: GlassCard(
                radius: AppRadius.tile,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                child: Text(l10n.printPreviewNote(printPreviewLimit), style: theme.textTheme.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}
