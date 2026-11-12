import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// 시작 단계 기록. 창은 `main`이 준비를 마친 뒤에야 보이므로(`windowManager.show`), 그 앞에서 예외가 나거나
/// 멈추면 창 없이 프로세스만 남는다(Windows 10에서 "앱이 안 열린다"는 보고). 단계마다 걸린 시간과 오류를
/// 파일에 남겨 원인을 알 수 있게 하고, 멈춘 단계는 [StartupLog.step]의 제한 시간 뒤에 건너뛴다.
///
/// 파일: Windows `%LOCALAPPDATA%\Daylight PDF\startup.log`, 그 밖에는 시스템 임시 폴더의
/// `daylight_pdf/startup.log`. 시작할 때마다 새로 쓴다(작게 유지). 기록에 실패해도 앱은 그대로 돈다.
class StartupLog {
  StartupLog._(this.file);

  /// 기록 파일. 만들지 못했으면 null(디버그 출력만 한다).
  final File? file;
  final _clock = Stopwatch()..start();

  /// 지금까지 실패하거나 시간이 넘은 단계가 있었는지.
  bool get hadProblems => _problems > 0;
  int _problems = 0;

  /// 기록 파일 위치. 플러그인을 거치지 않는다(플러그인 자체가 실패할 수 있으므로).
  static File defaultFile({bool? windows, Map<String, String>? environment, String? tempPath}) {
    final sep = Platform.pathSeparator;
    if (windows ?? Platform.isWindows) {
      final local = (environment ?? Platform.environment)['LOCALAPPDATA'];
      if (local != null && local.isNotEmpty) return File('$local${sep}Daylight PDF${sep}startup.log');
    }
    final temp = tempPath ?? Directory.systemTemp.path;
    return File('$temp${sep}daylight_pdf${sep}startup.log');
  }

  /// 기록을 시작한다. [file]을 주지 않으면 [defaultFile].
  static StartupLog start({File? file, List<String> args = const []}) {
    final chosen = file ?? defaultFile();
    File? target = chosen;
    try {
      chosen.parent.createSync(recursive: true);
      chosen.writeAsStringSync(
        'Daylight PDF startup ${DateTime.now().toIso8601String()}\n'
        'os: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n'
        'dart: ${Platform.version}\n'
        'args: ${args.length}\n',
      );
    } on Object catch (e) {
      debugPrint('startup log unavailable: $e');
      target = null;
    }
    return StartupLog._(target);
  }

  /// 한 줄 남긴다.
  void write(String line) {
    final text = '[${_clock.elapsedMilliseconds.toString().padLeft(6)} ms] $line';
    debugPrint(text);
    try {
      file?.writeAsStringSync('$text\n', mode: FileMode.append, flush: true);
    } on Object {
      // 기록 실패는 무시한다.
    }
  }

  /// 오류를 남긴다(앱이 돌고 있는 동안 잡히지 않은 오류도 여기로 온다).
  void error(String where, Object error, [StackTrace? stack]) {
    _problems++;
    write('ERROR $where: $error');
    if (stack != null) write(stack.toString().trimRight());
  }

  /// [name] 단계를 돌린다. 예외가 나면 기록하고 [fallback]을 돌려준다(없으면 다시 던진다).
  /// [timeout]이 지나도 끝나지 않으면 기록하고 [fallback]으로 넘어간다(없으면 [TimeoutException]).
  Future<T> step<T>(String name, Future<T> Function() body, {Duration? timeout, T Function()? fallback}) async {
    final started = _clock.elapsedMilliseconds;
    write('start $name');
    try {
      final future = body();
      final value = timeout == null ? await future : await future.timeout(timeout);
      write('done  $name (${_clock.elapsedMilliseconds - started} ms)');
      return value;
    } on TimeoutException catch (e, s) {
      error('$name timed out after ${timeout?.inMilliseconds} ms', e, s);
      if (fallback != null) return fallback();
      rethrow;
    } on Object catch (e, s) {
      error(name, e, s);
      if (fallback != null) return fallback();
      rethrow;
    }
  }
}
