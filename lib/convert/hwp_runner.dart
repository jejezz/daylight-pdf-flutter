import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 외부 프로그램을 한 번 돌린 결과.
class HwpProcessResult {
  const HwpProcessResult({required this.exitCode, this.stdout = '', this.stderr = '', this.timedOut = false});

  final int exitCode;
  final String stdout;
  final String stderr;

  /// 제한 시간이 지나 우리가 멈췄다. 이때 [exitCode]는 의미가 없다.
  final bool timedOut;
}

/// [HwpToPdf]가 변환기를 돌리는 방법. 시험에서는 가짜로 바꾼다.
/// 실행 파일을 찾을 수 없으면 [ProcessException]을 던진다.
typedef HwpProcessRunner =
    Future<HwpProcessResult> Function(
      String executable,
      List<String> arguments, {
      required Map<String, String> environment,
      required Duration timeout,
    });

/// 실제로 프로세스를 띄운다. 인자는 목록으로 넘기므로 셸을 거치지 않는다(파일 이름의 특수 문자가 명령이 되지 않는다).
Future<HwpProcessResult> runHwpProcess(
  String executable,
  List<String> arguments, {
  required Map<String, String> environment,
  required Duration timeout,
}) async {
  final process = await Process.start(executable, arguments, environment: environment);
  // 표준 입력을 기다리지 않게 닫는다.
  unawaited(process.stdin.close().catchError((Object _) {}));

  var timedOut = false;
  final timer = Timer(timeout, () {
    timedOut = true;
    process.kill();
  });
  const decoder = Utf8Decoder(allowMalformed: true);
  final out = process.stdout.transform(decoder).join();
  final err = process.stderr.transform(decoder).join();
  final code = await process.exitCode;
  timer.cancel();
  return HwpProcessResult(exitCode: code, stdout: await out, stderr: await err, timedOut: timedOut);
}
