import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../convert/conversion_error.dart';
import '../convert/error_text.dart';
import '../home/open_pdf.dart';
import '../home/recent_files.dart';
import '../l10n/app_localizations.dart';
import '../platform/new_window.dart';
import 'source_holder.dart';

XTypeGroup pdfTypeGroup(AppLocalizations l10n) => XTypeGroup(label: l10n.fileTypePdf, extensions: const ['pdf']);

Future<String?> pickPdf(AppLocalizations l10n) async =>
    (await openFile(acceptedTypeGroups: [pdfTypeGroup(l10n)]))?.path;

Future<List<String>> pickPdfs(AppLocalizations l10n) async => [
  for (final f in await openFiles(acceptedTypeGroups: [pdfTypeGroup(l10n)])) f.path,
];

/// 저장 위치를 고르게 한다. 취소하면 null. 확장자가 없으면 `.pdf`를 붙인다.
Future<String?> pickPdfSavePath(
  AppLocalizations l10n, {
  required String suggestedName,
  String? initialDirectory,
}) async {
  final location = await getSaveLocation(
    acceptedTypeGroups: [pdfTypeGroup(l10n)],
    suggestedName: suggestedName,
    initialDirectory: initialDirectory,
  );
  final path = location?.path;
  if (path == null) return null;
  return p.extension(path).toLowerCase() == '.pdf' ? path : '$path.pdf';
}

bool isPdf(String path) => p.extension(path).toLowerCase() == '.pdf';

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

/// 저장했다는 알림에 [path] 파일을 보기 화면에서 여는 단추를 붙여 보여 준다.
/// [actionLabel]을 주면 그 글자를 쓴다 (여러 파일을 만들었을 때 "첫 파일 열기").
void showSavedMessage(BuildContext context, String text, {required String path, String? actionLabel}) {
  final navigator = Navigator.of(context);
  final label = actionLabel ?? AppLocalizations.of(context).savedOpen;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      persist: false,
      duration: const Duration(seconds: 10),
      action: SnackBarAction(
        label: label,
        onPressed: () async {
          // 데스크톱은 새 창(새 프로세스)에서 연다. 띄우지 못하면(또는 모바일이면) 이 창에서 보기 화면으로 간다.
          if (canOpenNewWindow && await openInNewWindow(path)) return;
          await openPdf(navigator, path, recents: RecentFiles());
        },
      ),
    ),
  );
}

/// 저장하기 전에 부른다: [target]이 보기 화면이 열어 둔 파일이면 저장하는 동안 놓아 달라고 한다.
/// 돌려주는 값: true = 놓았다(저장이 끝나면 [SourceHolder.reacquire]를 불러야 한다), false = 놓을 필요 없다,
/// null = 놓을 수 없어서(저장하지 않은 주석) 저장하지 말아야 한다 (안내는 이미 보였다).
Future<bool?> releaseHeldTarget(BuildContext context, SourceHolder? holder, String target) async {
  if (holder == null || !p.equals(holder.path, target)) return false;
  final l10n = AppLocalizations.of(context);
  if (await holder.release()) return true;
  if (context.mounted) showMessage(context, l10n.pagesOverwriteUnsaved);
  return null;
}

/// 저장이 끝났다는 알림. [held]면(보기 화면이 그 파일을 다시 읽는다) [열기] 없이 글만 보이고, 아니면 [열기]가 붙는다.
void showSaved(BuildContext context, String text, {required String path, required bool held}) =>
    held ? showMessage(context, text) : showSavedMessage(context, text, path: path);

/// [action]을 돌리고 [ConversionException]은 사용자 문구로 보여 준다. 성공하면 true.
Future<bool> runReporting(BuildContext context, Future<void> Function() action) async {
  final l10n = AppLocalizations.of(context);
  try {
    await action();
    return true;
  } on ConversionException catch (e) {
    if (context.mounted) showMessage(context, conversionErrorText(l10n, e));
    return false;
  }
}
