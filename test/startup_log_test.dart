import 'dart:async';
import 'dart:io';

import 'package:daylight_pdf/platform/startup_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  late StartupLog log;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('startup_log_test');
    log = StartupLog.start(file: File('${dir.path}${Platform.pathSeparator}sub${Platform.pathSeparator}startup.log'));
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String text() => log.file!.readAsStringSync();

  test('creates the folder and records each step with its result', () async {
    expect(await log.step('ok', () async => 42), 42);
    expect(text(), contains('start ok'));
    expect(text(), contains('done  ok'));
    expect(log.hadProblems, isFalse);
  });

  test('a failing step is recorded and falls back', () async {
    final value = await log.step<int>('bad', () async => throw StateError('boom'), fallback: () => 7);
    expect(value, 7);
    expect(text(), contains('ERROR bad: Bad state: boom'));
    expect(log.hadProblems, isTrue);
  });

  test('a failing step without fallback rethrows', () async {
    await expectLater(log.step<int>('bad', () async => throw StateError('boom')), throwsStateError);
    expect(text(), contains('ERROR bad'));
  });

  test('a step that never finishes times out and falls back', () async {
    final never = Completer<int>();
    final value = await log.step('hang', () => never.future, timeout: const Duration(milliseconds: 50), fallback: () => -1);
    expect(value, -1);
    expect(text(), contains('ERROR hang timed out after 50 ms'));
  });

  test('default file: LOCALAPPDATA on Windows, temp folder elsewhere', () {
    final sep = Platform.pathSeparator;
    expect(
      StartupLog.defaultFile(windows: true, environment: {'LOCALAPPDATA': 'L'}).path,
      'L${sep}Daylight PDF${sep}startup.log',
    );
    expect(StartupLog.defaultFile(windows: false, tempPath: 'T').path, 'T${sep}daylight_pdf${sep}startup.log');
    expect(StartupLog.defaultFile(windows: true, environment: const {}, tempPath: 'T').path, 'T${sep}daylight_pdf${sep}startup.log');
  });

  test('an unwritable location still gives a working log', () async {
    final blocker = File('${dir.path}${Platform.pathSeparator}blocker')..writeAsStringSync('x');
    final broken = StartupLog.start(file: File('${blocker.path}${Platform.pathSeparator}startup.log'));
    expect(broken.file, isNull);
    expect(await broken.step('ok', () async => 1), 1);
  });
}
