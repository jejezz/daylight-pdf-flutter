import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../convert/ai_to_pdf.dart';
import '../convert/convert_screen.dart';
import '../convert/image_to_pdf.dart';
import 'open_pdf.dart';
import 'recent_files.dart';

/// 운영체제에 등록한 형식 중 보기 화면으로 여는 것 (점 없이).
const viewerExtensions = ['pdf'];

/// 운영체제에 등록한 형식 중 변환 화면으로 여는 것 (점 없이).
/// 설치 파일·Info.plist·Linux `.desktop`에 등록한 확장자와 같게 둔다.
final convertExtensions = ['ai', 'svg', ...ImageToPdf.extensions];

/// 운영체제가 이 앱으로 열어 줄 수 있는 파일인가: PDF, PDF 호환 `.ai`, SVG, 변환할 수 있는 이미지.
bool isOpenableFile(String path) {
  final ext = p.extension(path).toLowerCase();
  return ext == '.pdf' || ext == '.svg' || AiToPdf.supports(path) || ImageToPdf.supports(path);
}

/// 명령줄 인자(Windows·Linux에서 파일을 더블클릭하거나 "연결 프로그램"으로 열면 경로가 온다)에서 열 파일을 고른다.
/// 옵션(`--new-window` 등)과 없는 파일, 열 수 없는 형식은 뺀다.
List<String> filesFromArguments(List<String> args) => [
  for (final arg in args)
    if (!arg.startsWith('--') && isOpenableFile(arg) && File(arg).existsSync()) arg,
];

/// 운영체제가 넘겨 준 파일을 연다. 홈에 끌어놓았을 때와 같다: PDF 한 개면 보기 화면, 그 밖에는 변환 화면에 담는다.
Future<void> openFiles(NavigatorState navigator, List<String> paths, {RecentFiles? recents}) async {
  if (paths.isEmpty) return;
  if (paths.length == 1 && p.extension(paths.first).toLowerCase() == '.pdf') {
    await openPdf(navigator, paths.first, recents: recents ?? RecentFiles());
    return;
  }
  await navigator.push(MaterialPageRoute<void>(builder: (_) => ConvertScreen(initialPaths: paths)));
}
