import 'dart:convert';
import 'dart:io';

import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/hwp_runner.dart';
import 'package:daylight_pdf/convert/hwp_to_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// rhwp `--json` 출력 흉내. 글꼴 이름은 UTF-8 JSON 그대로다.
String _json({List<Object?> unavailable = const []}) => jsonEncode({
  'backend': 'svg',
  'pageCount': 1,
  'nativeFontSupply': {'unavailable': unavailable, 'mappings': {}},
});

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('hwp_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  group('확장자와 명령줄', () {
    test('HWP 계열만 지원한다 (대소문자 무관)', () {
      for (final name in ['a.hwp', 'a.HWPX', 'b.Hml', r'C:\문서\보고서.hwp']) {
        expect(HwpToPdf.supports(name), isTrue, reason: name);
      }
      for (final name in ['a.pdf', 'a.hwpx.txt', 'a.doc', 'hwp', 'a.hwpp']) {
        expect(HwpToPdf.supports(name), isFalse, reason: name);
      }
    });

    test('대체 글꼴은 운영체제별로 정한다', () {
      expect(hwpFallbackFonts('windows').sans, 'Malgun Gothic');
      expect(hwpFallbackFonts('macos').sans, 'Apple SD Gothic Neo');
      expect(hwpFallbackFonts('linux').serif, 'Noto Serif CJK KR');
      expect(hwpFallbackFonts('fuchsia').mono, isNotEmpty);
    });

    test('입력은 절대 경로로 넘기고 글꼴 옵션을 붙인다', () {
      final args = HwpToPdf.arguments('-weird.hwp', '/out/a.pdf.tmp', hwpFallbackFonts('windows'));
      expect(args.first, 'export-pdf');
      expect(args[1], p.absolute('-weird.hwp'));
      expect(args[1].startsWith('-'), isFalse, reason: '옵션으로 읽히면 안 된다');
      expect(args, containsAllInOrder(['-o', '/out/a.pdf.tmp', '--json']));
      expect(args, containsAllInOrder(['--fallback-serif', 'Batang', '--fallback-sans', 'Malgun Gothic']));
    });

    test('변환기는 운영체제별 위치에서 찾는다', () {
      // path 패키지는 실행 중인 시스템의 구분자를 쓰므로 `/`로 맞춰 비교한다.
      String where(String os, String exe) => HwpToPdf.executablePathFor(os, exe).replaceAll(r'\', '/');
      expect(where('windows', r'C:\Apps\Daylight PDF\daylight_pdf.exe'), endsWith('Daylight PDF/rhwp/rhwp.exe'));
      expect(where('linux', '/opt/daylight/daylight_pdf'), '/opt/daylight/rhwp/rhwp');
      expect(
        where('macos', '/Applications/Daylight PDF.app/Contents/MacOS/Daylight PDF'),
        '/Applications/Daylight PDF.app/Contents/Helpers/rhwp',
      );
    });

    test('글꼴 내려받기를 끄는 환경변수', () {
      final env = HwpToPdf.environment('/tmp/cache');
      expect(env['RHWP_WEBFONT_OFFLINE'], '1');
      expect(env['RHWP_WEBFONT_CACHE'], '/tmp/cache');
    });
  });

  group('찾지 못한 글꼴 읽기', () {
    test('사유를 떼고 같은 이름은 한 번만 센다', () {
      final out = _json(
        unavailable: ['한양신명조', '한양신명조: 오프라인 모드이며 검증된 캐시가 없습니다', '함초롬돋움: 오프라인 모드이며 검증된 캐시가 없습니다'],
      );
      expect(HwpToPdf.unavailableFonts(out), ['한양신명조', '함초롬돋움']);
    });

    test('제어 문자는 지우고 긴 이름은 줄이며 빈 이름은 건너뛴다', () {
      final out = _json(unavailable: ['A\u0000B\n', '   ', ''.padRight(200, 'x'), 7, null]);
      final names = HwpToPdf.unavailableFonts(out);
      expect(names.first, 'AB');
      expect(names, hasLength(2));
      expect(names.last.length, lessThanOrEqualTo(61));
      expect(names.last.endsWith('…'), isTrue);
    });

    test('너무 많으면 100개에서 멈춘다', () {
      final out = _json(unavailable: [for (var i = 0; i < 500; i++) 'font$i']);
      expect(HwpToPdf.unavailableFonts(out), hasLength(100));
    });

    test('JSON이 아니거나 모양이 달라도 빈 목록이다', () {
      expect(HwpToPdf.unavailableFonts(''), isEmpty);
      expect(HwpToPdf.unavailableFonts('not json'), isEmpty);
      expect(HwpToPdf.unavailableFonts('[]'), isEmpty);
      expect(HwpToPdf.unavailableFonts('{"nativeFontSupply": 3}'), isEmpty);
      expect(HwpToPdf.unavailableFonts('{"nativeFontSupply": {"unavailable": "x"}}'), isEmpty);
    });
  });

  group('convert', () {
    late String input;
    late String output;
    setUp(() {
      input = p.join(dir.path, '보고서.hwp');
      File(input).writeAsBytesSync([1, 2, 3]);
      output = p.join(dir.path, '보고서.pdf');
    });

    /// 가짜 변환기: `-o` 뒤의 경로에 PDF 흉내를 쓰고 [stdout]을 돌려준다.
    HwpProcessRunner fake({
      int exitCode = 0,
      String stdout = '',
      String stderr = '',
      bool timedOut = false,
      bool writeOutput = true,
      void Function(List<String> args, Map<String, String> env)? onCall,
    }) => (exe, args, {required environment, required timeout}) async {
      onCall?.call(args, environment);
      if (writeOutput) File(args[args.indexOf('-o') + 1]).writeAsBytesSync(utf8.encode('%PDF-1.7 fake'));
      return HwpProcessResult(exitCode: exitCode, stdout: stdout, stderr: stderr, timedOut: timedOut);
    };

    Future<void> expectFails(ConversionErrorKind kind, HwpProcessRunner runner) async {
      await expectLater(
        HwpToPdf.convert(input, output, runner: runner, executable: 'rhwp'),
        throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', kind)),
      );
      expect(File(output).existsSync(), isFalse, reason: '실패하면 결과 파일이 없어야 한다');
      expect(File('$output.tmp').existsSync(), isFalse, reason: '임시 파일이 남으면 안 된다');
    }

    test('성공하면 .tmp를 최종 이름으로 바꾸고 경고가 없다', () async {
      List<String>? seenArgs;
      Map<String, String>? seenEnv;
      final warnings = await HwpToPdf.convert(
        input,
        output,
        runner: fake(stdout: _json(), onCall: (a, e) => (seenArgs, seenEnv) = (a, e)),
        executable: 'rhwp',
        cacheDir: '/cache',
      );
      expect(warnings, isEmpty);
      expect(File(output).readAsStringSync(), startsWith('%PDF'));
      expect(File('$output.tmp').existsSync(), isFalse);
      expect(seenArgs![seenArgs!.indexOf('-o') + 1], '$output.tmp');
      expect(seenEnv, {'RHWP_WEBFONT_OFFLINE': '1', 'RHWP_WEBFONT_CACHE': '/cache'});
    });

    test('못 찾은 글꼴이 있으면 경고로 돌려준다', () async {
      final warnings = await HwpToPdf.convert(
        input,
        output,
        runner: fake(stdout: _json(unavailable: ['한양신명조', '함초롬바탕: 사유'])),
        executable: 'rhwp',
      );
      expect(warnings, hasLength(1));
      expect(warnings.single.kind, ConversionWarningKind.fontsSubstituted);
      expect(warnings.single.items, ['한양신명조', '함초롬바탕']);
      expect(File(output).existsSync(), isTrue);
    });

    test('암호 문서(종료 코드 2 + 비밀번호 안내)', () async {
      await expectFails(
        ConversionErrorKind.passwordProtected,
        fake(exitCode: 2, stderr: '오류: 비밀번호가 필요한 암호 문서입니다', writeOutput: false),
      );
    });

    test('읽을 수 없는 파일(종료 코드 1)은 cannotRead', () async {
      await expectFails(ConversionErrorKind.cannotRead, fake(exitCode: 1, stderr: '오류: 문서 파싱 실패', writeOutput: false));
    });

    test('종료 코드 2라도 비밀번호 얘기가 아니면 cannotRead', () async {
      await expectFails(ConversionErrorKind.cannotRead, fake(exitCode: 2, stderr: 'usage error', writeOutput: false));
    });

    test('실패하며 남긴 임시 파일도 지운다', () async {
      await expectFails(ConversionErrorKind.cannotRead, fake(exitCode: 1, writeOutput: true));
    });

    test('제한 시간을 넘기면 conversionTimeout', () async {
      await expectFails(ConversionErrorKind.conversionTimeout, fake(exitCode: -1, timedOut: true));
    });

    test('종료 코드 0인데 결과가 없거나 비어 있으면 cannotRead', () async {
      await expectFails(ConversionErrorKind.cannotRead, fake(writeOutput: false));
      await expectFails(ConversionErrorKind.cannotRead, (exe, args, {required environment, required timeout}) async {
        File(args[args.indexOf('-o') + 1]).writeAsBytesSync([]);
        return const HwpProcessResult(exitCode: 0);
      });
    });

    test('변환기를 실행할 수 없으면 converterMissing', () async {
      await expectFails(
        ConversionErrorKind.converterMissing,
        (exe, args, {required environment, required timeout}) => throw const ProcessException('rhwp', []),
      );
    });

    test('오류에는 파일 이름만 담는다 (경로 아님)', () async {
      try {
        await HwpToPdf.convert(input, output, runner: fake(exitCode: 1, writeOutput: false), executable: 'rhwp');
        fail('던져야 한다');
      } on ConversionException catch (e) {
        expect(e.fileName, '보고서.hwp');
      }
    });
  });

  test('실제 프로세스: 없는 실행 파일은 ProcessException', () async {
    await expectLater(
      runHwpProcess(p.join(dir.path, 'nothing.exe'), [], environment: {}, timeout: const Duration(seconds: 5)),
      throwsA(isA<ProcessException>()),
    );
  });
}
