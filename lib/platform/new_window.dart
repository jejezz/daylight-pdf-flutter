import 'dart:io';

import 'package:flutter/foundation.dart';

/// 새 창으로 열 수 있는 플랫폼인가 (데스크톱만).
bool get canOpenNewWindow => Platform.isMacOS || Platform.isWindows || Platform.isLinux;

/// 새 창을 띄우는 함수. 시험에서 바꿔 끼운다 (진짜 프로세스를 띄우지 않게).
@visibleForTesting
Future<bool> Function(String path)? newWindowLauncherForTest;

/// [path]를 이 앱의 새 프로세스(= 새 창)에서 연다. 띄우지 못하면 false.
/// 새 프로세스는 명령줄로 받은 PDF를 시작하자마자 연다(`main`의 `pdfFromArguments`). `--new-window`는 창을 이전 창과 어긋나게 둔다.
Future<bool> openInNewWindow(String path) async {
  final test = newWindowLauncherForTest;
  if (test != null) return test(path);
  if (!canOpenNewWindow) return false;
  try {
    if (Platform.isMacOS) {
      // 실행 파일을 직접 부르면 Dock·번들 정보가 어긋난다. 번들(.app)을 새 인스턴스로 연다.
      final exe = Platform.resolvedExecutable; // .../Daylight PDF.app/Contents/MacOS/Daylight PDF
      final end = exe.indexOf('.app/');
      if (end < 0) return false;
      await Process.start('open', ['-n', exe.substring(0, end + 4), '--args', '--new-window', path], mode: ProcessStartMode.detached);
    } else {
      await Process.start(Platform.resolvedExecutable, ['--new-window', path], mode: ProcessStartMode.detached);
    }
    return true;
  } on Object {
    return false;
  }
}
