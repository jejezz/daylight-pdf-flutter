import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../convert/conversion_error.dart';
import '../convert/error_text.dart';
import '../l10n/app_localizations.dart';

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
