import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../window/focus_tint.dart';
import 'ai_to_pdf.dart';
import 'conversion_error.dart';
import 'conversion_queue.dart';
import 'image_to_pdf.dart';
import 'output_paths.dart';
import 'pdf_to_images.dart';
import 'svg_to_pdf.dart';

bool _isPdf(String path) => p.extension(path).toLowerCase() == '.pdf';

/// 변환 화면. 이미지는 PDF로, PDF는 쪽별 이미지로 바꾼다. 파일을 여러 개 놓으면 큐가 차례로 처리한다.
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
  bool _dragging = false;

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
        XTypeGroup(label: l10n.convertFileTypes, extensions: [...ImageToPdf.extensions, 'pdf']),
      ],
    );
    if (files.isNotEmpty && mounted) _addPaths(files.map((f) => f.path).toList());
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
        _toPdfJob(svg, (input, output) => SvgToPdf.convert(input, output, loadFallbackFonts: _loadFallbackFonts)),
      );
    }
    for (final ai in ais) {
      _queue.add(_toPdfJob(ai, AiToPdf.convert));
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
  ConversionJob _toPdfJob(String input, Future<void> Function(String input, String output) convert) {
    return ConversionJob(
      label: p.basename(input),
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
      run: () => PdfToImages.convert(
        input,
        uniquePath(p.join(_dirFor(input), p.basenameWithoutExtension(input))),
        format: format,
        dpi: dpi,
      ),
    );
  }

  String _errorText(AppLocalizations l10n, ConversionException e) => switch (e.kind) {
    ConversionErrorKind.unsupportedFormat => l10n.errUnsupportedFormat(e.fileName),
    ConversionErrorKind.cannotRead => l10n.errCannotRead(e.fileName),
    ConversionErrorKind.passwordProtected => l10n.errPasswordProtected(e.fileName),
    ConversionErrorKind.writeFailed => l10n.errWriteFailed(e.fileName),
    ConversionErrorKind.notPdfCompatible => l10n.errNotPdfCompatible(e.fileName),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: const FocusTint(),
        title: Text(l10n.convertTitle),
        actions: [
          IconButton(
            tooltip: l10n.convertClearFinished,
            icon: const Icon(Icons.playlist_remove_rounded),
            onPressed: _queue.clearFinished,
          ),
          IconButton(tooltip: l10n.convertAddFiles, icon: const Icon(Icons.add_rounded), onPressed: _pickFiles),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(value: _mergeImages, onChanged: (v) => setState(() => _mergeImages = v)),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.convertMergeImages),
                  ],
                ),
                SegmentedButton<RasterFormat>(
                  showSelectedIcon: false,
                  segments: [
                    for (final f in RasterFormat.values) ButtonSegment(value: f, label: Text(f.name.toUpperCase())),
                  ],
                  selected: {_format},
                  onSelectionChanged: (s) => setState(() => _format = s.first),
                ),
                DropdownButton<int>(
                  value: _dpi,
                  items: [
                    for (final d in PdfToImages.dpiChoices) DropdownMenuItem(value: d, child: Text(l10n.convertDpi(d))),
                  ],
                  onChanged: (v) => setState(() => _dpi = v ?? _dpi),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(_outputDir == null ? l10n.convertOutputSame : p.basename(_outputDir!)),
                  onPressed: _pickOutputDir,
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
          const Divider(height: 1),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => _dragging = true),
              onDragExited: (_) => setState(() => _dragging = false),
              onDragDone: (details) {
                setState(() => _dragging = false);
                _addPaths(details.files.map((f) => f.path).toList());
              },
              child: Container(
                color: _dragging ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
                child: ListenableBuilder(
                  listenable: _queue,
                  builder: (context, _) {
                    final jobs = _queue.jobs;
                    if (jobs.isEmpty) {
                      return Center(child: Text(l10n.convertEmpty, style: theme.textTheme.titleMedium));
                    }
                    return ListView.separated(
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final job = jobs[i];
                        return ListTile(
                          leading: switch (job.status) {
                            JobStatus.pending => const Icon(Icons.schedule_rounded),
                            JobStatus.running => const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            JobStatus.done => Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary),
                            JobStatus.failed => Icon(Icons.error_rounded, color: theme.colorScheme.error),
                          },
                          title: Text(job.label, overflow: TextOverflow.ellipsis),
                          subtitle: switch (job.status) {
                            JobStatus.done => Text(
                              job.outputs.length == 1
                                  ? p.basename(job.outputs.first)
                                  : l10n.convertFilesCreated(job.outputs.length),
                              overflow: TextOverflow.ellipsis,
                            ),
                            JobStatus.failed => Text(
                              _errorText(l10n, job.error!),
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                            _ => null,
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
