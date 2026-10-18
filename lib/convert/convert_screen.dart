import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../widgets/drop_zone.dart';
import '../widgets/glass_card.dart';
import '../widgets/status_pill.dart';
import '../widgets/tool_chip.dart';
import '../window/focus_tint.dart';
import 'ai_to_pdf.dart';
import 'conversion_queue.dart';
import 'error_text.dart';
import 'image_to_pdf.dart';
import 'output_paths.dart';
import 'pdf_to_images.dart';
import 'reveal.dart';
import 'svg_to_pdf.dart';

bool _isPdf(String path) => p.extension(path).toLowerCase() == '.pdf';

/// 변환 화면. 이미지·SVG·AI는 PDF로, PDF는 쪽별 이미지로 바꾼다. 파일을 여러 개 놓으면 큐가 차례로 처리한다.
/// 왼쪽은 옵션 카드(이미지→PDF, PDF→이미지, 저장 위치), 오른쪽은 끌어놓기 영역과 대기열.
class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key, this.initialPaths = const []});

  final List<String> initialPaths;

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen> {
  final _queue = ConversionQueue();
  bool _mergeImages = false;
  RasterFormat _format = RasterFormat.png;
  int _dpi = 150;
  String? _outputDir;

  @override
  void initState() {
    super.initState();
    if (widget.initialPaths.isNotEmpty) {
      // 첫 프레임 뒤에 추가해야 SnackBar 에 쓸 context 가 준비된다.
      WidgetsBinding.instance.addPostFrameCallback((_) => _addPaths(widget.initialPaths));
    }
  }

  @override
  void dispose() {
    _queue.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    final l10n = AppLocalizations.of(context);
    final files = await openFiles(
      acceptedTypeGroups: [
        XTypeGroup(label: l10n.convertFileTypes, extensions: [...ImageToPdf.extensions, 'svg', 'ai', 'pdf']),
      ],
    );
    if (files.isNotEmpty && mounted) {
      _addPaths(files.map((f) => f.path).toList());
    }
  }

  Future<void> _pickOutputDir() async {
    final dir = await getDirectoryPath();
    if (dir != null && mounted) setState(() => _outputDir = dir);
  }

  void _addPaths(List<String> paths) {
    final l10n = AppLocalizations.of(context);
    final images = paths.where(ImageToPdf.supports).toList();
    final pdfs = paths.where(_isPdf).toList();
    final svgs = paths.where(SvgToPdf.supports).toList();
    final ais = paths.where(AiToPdf.supports).toList();
    final skipped = paths
        .where((x) => !ImageToPdf.supports(x) && !_isPdf(x) && !SvgToPdf.supports(x) && !AiToPdf.supports(x))
        .map(p.basename)
        .toList();

    if (images.isNotEmpty) {
      if (_mergeImages) {
        _queue.add(_imagesJob(images));
      } else {
        for (final image in images) {
          _queue.add(_imagesJob([image]));
        }
      }
    }
    for (final svg in svgs) {
      _queue.add(
        _toPdfJob(
          svg,
          JobKind.svg,
          (input, output) => SvgToPdf.convert(input, output, loadFallbackFonts: _loadFallbackFonts),
        ),
      );
    }
    for (final ai in ais) {
      _queue.add(_toPdfJob(ai, JobKind.ai, AiToPdf.convert));
    }
    for (final pdf in pdfs) {
      _queue.add(_pdfJob(pdf));
    }
    if (skipped.isNotEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.convertSkipped(skipped.length, skipped.join(', ')))));
    }
  }

  String _dirFor(String firstInput) => _outputDir ?? p.dirname(firstInput);

  ConversionJob _imagesJob(List<String> inputs) {
    final first = inputs.first;
    final label = inputs.length == 1 ? p.basename(first) : '${p.basename(first)} +${inputs.length - 1}';
    return ConversionJob(
      label: label,
      kind: JobKind.image,
      run: () async {
        final out = uniquePath(p.join(_dirFor(first), '${p.basenameWithoutExtension(first)}.pdf'));
        await ImageToPdf.convert(inputs, out);
        return [out];
      },
    );
  }

  /// SVG 글자에 한글 등이 있을 때 쓰는 대체 글꼴 — 앱에 이미 들어 있는 SeoulNamsan.
  static Future<SvgFallbackFonts> _loadFallbackFonts() async {
    final regular = await rootBundle.load('assets/fonts/seoul_namsan_regular.ttf');
    final bold = await rootBundle.load('assets/fonts/seoul_namsan_bold.ttf');
    return (
      regular: regular.buffer.asUint8List(regular.offsetInBytes, regular.lengthInBytes),
      bold: bold.buffer.asUint8List(bold.offsetInBytes, bold.lengthInBytes),
    );
  }

  /// 파일 하나를 같은 이름의 PDF 하나로 바꾸는 작업 (SVG, AI).
  ConversionJob _toPdfJob(String input, JobKind kind, Future<void> Function(String input, String output) convert) {
    return ConversionJob(
      label: p.basename(input),
      kind: kind,
      run: () async {
        final out = uniquePath(p.join(_dirFor(input), '${p.basenameWithoutExtension(input)}.pdf'));
        await convert(input, out);
        return [out];
      },
    );
  }

  ConversionJob _pdfJob(String input) {
    final format = _format, dpi = _dpi;
    return ConversionJob(
      label: p.basename(input),
      kind: JobKind.pdf,
      run: () => PdfToImages.convert(
        input,
        uniquePath(p.join(_dirFor(input), p.basenameWithoutExtension(input))),
        format: format,
        dpi: dpi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.convertTitle),
        actions: const [SizedBox(width: AppSpacing.sm)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 300, child: SingleChildScrollView(child: _options(l10n, theme))),
            const SizedBox(width: AppSpacing.xl),
            Expanded(child: _queuePane(l10n, theme)),
          ],
        ),
      ),
    );
  }

  Widget _options(AppLocalizations l10n, ThemeData theme) {
    Widget section(IconData icon, String title, Widget body) => GlassCard(
      radius: AppRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          body,
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Icons.image_outlined,
          l10n.convertSectionImages,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.convertMergeImages, style: theme.textTheme.bodyMedium)),
                  Switch(value: _mergeImages, onChanged: (v) => setState(() => _mergeImages = v)),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(l10n.convertImagesNote, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        section(
          Icons.picture_as_pdf_outlined,
          l10n.convertSectionPdf,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.convertFormatLabel, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<RasterFormat>(
                showSelectedIcon: false,
                segments: [
                  for (final f in RasterFormat.values) ButtonSegment(value: f, label: Text(f.name.toUpperCase())),
                ],
                selected: {_format},
                onSelectionChanged: (s) => setState(() => _format = s.first),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(l10n.convertResolutionLabel, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  for (final d in PdfToImages.dpiChoices) ButtonSegment(value: d, label: Text(l10n.convertDpi(d))),
                ],
                selected: {_dpi},
                onSelectionChanged: (s) => setState(() => _dpi = s.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        section(
          Icons.folder_outlined,
          l10n.convertSectionOutput,
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickOutputDir,
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: Text(
                    _outputDir == null ? l10n.convertOutputSame : p.basename(_outputDir!),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (_outputDir != null)
                IconButton(
                  tooltip: l10n.convertOutputSame,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _outputDir = null),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _queuePane(AppLocalizations l10n, ThemeData theme) {
    return ListenableBuilder(
      listenable: _queue,
      builder: (context, _) {
        final jobs = _queue.jobs;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropZone(
              onDrop: _addPaths,
              radius: AppRadius.tile,
              padding: EdgeInsets.symmetric(
                vertical: jobs.isEmpty ? AppSpacing.xxl * 2 : AppSpacing.lg,
                horizontal: AppSpacing.lg,
              ),
              child: jobs.isEmpty
                  ? Column(
                      children: [
                        Icon(Icons.upload_file_rounded, size: 44, color: theme.colorScheme.primary),
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.convertEmpty, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton.icon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.convertAddFiles),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.upload_file_rounded, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(l10n.convertEmpty, style: theme.textTheme.bodyMedium)),
                        FilledButton.tonalIcon(
                          onPressed: _pickFiles,
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(l10n.convertAddFiles),
                        ),
                      ],
                    ),
            ),
            if (jobs.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Text(l10n.convertQueueTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(width: AppSpacing.sm),
                  StatusPill(label: '${jobs.length}'),
                  const Spacer(),
                  ToolChip(
                    icon: Icons.playlist_remove_rounded,
                    label: l10n.convertClearFinished,
                    onPressed: _queue.clearFinished,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView.separated(
                  itemCount: jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _JobCard(job: jobs[i]),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// 대기열 한 줄: 종류 아이콘, 이름, 결과/오류 설명, 상태 알약, 결과 열기.
class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final ConversionJob job;

  static IconData _icon(JobKind kind) => switch (kind) {
    JobKind.image => Icons.image_outlined,
    JobKind.svg => Icons.polyline_outlined,
    JobKind.ai => Icons.auto_awesome_mosaic_outlined,
    JobKind.pdf => Icons.picture_as_pdf_outlined,
    JobKind.other => Icons.insert_drive_file_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final (label, tone, icon) = switch (job.status) {
      JobStatus.pending => (l10n.convertStatusPending, PillTone.neutral, Icons.schedule_rounded),
      JobStatus.running => (l10n.convertStatusRunning, PillTone.info, Icons.autorenew_rounded),
      JobStatus.done => (l10n.convertStatusDone, PillTone.success, Icons.check_rounded),
      JobStatus.failed => (l10n.convertStatusFailed, PillTone.danger, Icons.error_outline_rounded),
    };
    final detail = switch (job.status) {
      JobStatus.done =>
        job.outputs.length == 1 ? p.basename(job.outputs.first) : l10n.convertFilesCreated(job.outputs.length),
      JobStatus.failed => conversionErrorText(l10n, job.error!),
      _ => null,
    };
    return GlassCard(
      radius: AppRadius.tile,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.button),
            ),
            child: Icon(_icon(job.kind), size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.label, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                if (detail != null)
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: job.status == JobStatus.failed ? theme.colorScheme.error : null,
                    ),
                  ),
              ],
            ),
          ),
          if (job.status == JobStatus.done) ...[
            if (job.outputs.length == 1)
              ToolChip(
                icon: Icons.open_in_new_rounded,
                label: l10n.convertOpenResult,
                compact: true,
                onPressed: () => openResult(job.outputs.first),
              ),
            ToolChip(
              icon: Icons.folder_open_rounded,
              label: l10n.convertReveal,
              compact: true,
              onPressed: job.outputs.isEmpty ? null : () => revealInFolder(job.outputs.first),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (job.status == JobStatus.running)
            const Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm),
              child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          StatusPill(label: label, tone: tone, icon: icon),
        ],
      ),
    );
  }
}
