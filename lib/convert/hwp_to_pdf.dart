import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import 'conversion_error.dart';
import 'hwp_runner.dart';

/// 문서에 쓰인 글꼴을 이 컴퓨터에서 못 찾았을 때 대신 쓸 운영체제 글꼴 이름(글꼴 패밀리 이름).
class HwpFallbackFonts {
  const HwpFallbackFonts({required this.serif, required this.sans, required this.mono});

  final String serif;
  final String sans;
  final String mono;
}

/// 운영체제별 대체 글꼴. **Windows만 실제로 시험했다.** macOS·Linux 값은 그 시스템의 기본 한글 글꼴 이름을 적은 것이라
/// 이름이 다르면 rhwp가 못 찾았다고 알릴 뿐 변환은 된다(그 시스템의 기본 글꼴로 그려진다).
HwpFallbackFonts hwpFallbackFonts(String operatingSystem) => switch (operatingSystem) {
  'windows' => const HwpFallbackFonts(serif: 'Batang', sans: 'Malgun Gothic', mono: 'Consolas'),
  'macos' => const HwpFallbackFonts(serif: 'AppleMyungjo', sans: 'Apple SD Gothic Neo', mono: 'Menlo'),
  _ => const HwpFallbackFonts(serif: 'Noto Serif CJK KR', sans: 'Noto Sans CJK KR', mono: 'DejaVu Sans Mono'),
};

/// HWP·HWPX·HML → PDF. 변환은 rhwp(MIT, https://github.com/edwardkim/rhwp) 명령줄 도구가 한다.
///
/// 글꼴은 앱에 넣지도, 인터넷에서 받지도 않는다. rhwp를 **오프라인 모드**로 돌려 운영체제에 설치된 글꼴만 쓰고,
/// 없는 글꼴은 [HwpFallbackFonts]로 바꾼다. 바꾼 글꼴이 있으면 [ConversionWarning]으로 돌려줘서 UI가 알린다.
abstract final class HwpToPdf {
  /// 점 없는 소문자 확장자. `open_files.dart`·설치 파일·`Info.plist`·Linux `.desktop`에 등록한 목록과 같게 둔다.
  static const extensions = ['hwp', 'hwpx', 'hml'];

  /// 시험에서 실제 프로세스 대신 쓸 실행기. 화면 시험이 변환기를 띄우지 않게 한다.
  @visibleForTesting
  static HwpProcessRunner? runnerForTest;

  /// 변환기 파일을 다른 곳에서 쓰도록 지정하는 환경변수(개발·시험용).
  static const executableEnv = 'DAYLIGHT_RHWP';

  /// rhwp가 한 번 도는 데 허용하는 시간. 151쪽 문서가 4분쯤 걸렸다.
  static const defaultTimeout = Duration(minutes: 15);

  static bool supports(String path) => extensions.contains(p.extension(path).toLowerCase().replaceFirst('.', ''));

  /// 앱과 함께 설치된 변환기 위치. 환경변수 [executableEnv]가 있으면 그것을 쓴다.
  static String executablePath() {
    final override = Platform.environment[executableEnv];
    if (override != null && override.isNotEmpty) return override;
    return executablePathFor(Platform.operatingSystem, Platform.resolvedExecutable);
  }

  /// 운영체제별 설치 위치(순수 함수, 시험용으로 나눴다).
  /// Windows·Linux: 실행 파일 옆 `rhwp/` 폴더. macOS: 앱 번들의 `Contents/Helpers/rhwp`(Apple이 도우미 실행 파일을 두라는 곳이고
  /// 앱 서명 때 함께 서명된다).
  static String executablePathFor(String operatingSystem, String resolvedExecutable) {
    final dir = p.dirname(resolvedExecutable);
    return switch (operatingSystem) {
      'windows' => p.join(dir, 'rhwp', 'rhwp.exe'),
      'macos' => p.normalize(p.join(dir, '..', 'Helpers', 'rhwp')),
      _ => p.join(dir, 'rhwp', 'rhwp'),
    };
  }

  /// rhwp에 넘길 명령줄. 입력은 절대 경로로 바꿔 `-`로 시작하는 파일 이름이 옵션으로 읽히지 않게 한다.
  static List<String> arguments(String input, String output, HwpFallbackFonts fonts) => [
    'export-pdf',
    p.absolute(input),
    '-o',
    output,
    '--json',
    '--fallback-serif',
    fonts.serif,
    '--fallback-sans',
    fonts.sans,
    '--fallback-mono',
    fonts.mono,
  ];

  /// 글꼴 내려받기를 막는 환경변수. 캐시 위치는 쓰이지 않는 임시 폴더로 돌린다(사용자 폴더에 글꼴이 쌓이지 않게).
  static Map<String, String> environment(String cacheDir) => {'RHWP_WEBFONT_OFFLINE': '1', 'RHWP_WEBFONT_CACHE': cacheDir};

  /// [input]을 [outputPath]로 바꾼다. 글꼴을 바꿔 그렸으면 그 경고를 돌려준다.
  /// 출력은 `.tmp`에 먼저 쓰고 이름을 바꿔 넣는다(중간에 멈춰도 반쯤 쓰인 PDF가 남지 않는다).
  static Future<List<ConversionWarning>> convert(
    String input,
    String outputPath, {
    HwpProcessRunner? runner,
    String? executable,
    Duration timeout = defaultTimeout,
    String? cacheDir,
    HwpFallbackFonts? fonts,
  }) async {
    final name = p.basename(input);
    final tmp = '$outputPath.tmp';
    final HwpProcessResult result;
    try {
      result = await (runner ?? runnerForTest ?? runHwpProcess)(
        executable ?? executablePath(),
        arguments(input, tmp, fonts ?? hwpFallbackFonts(Platform.operatingSystem)),
        environment: environment(cacheDir ?? p.join(Directory.systemTemp.path, 'daylight_pdf', 'rhwp_fonts')),
        timeout: timeout,
      );
    } on ProcessException {
      throw ConversionException(ConversionErrorKind.converterMissing, fileName: name);
    }

    try {
      if (result.timedOut) throw ConversionException(ConversionErrorKind.conversionTimeout, fileName: name);
      if (result.exitCode != 0) throw ConversionException(_errorKind(result), fileName: name);
      final file = File(tmp);
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
      }
      try {
        file.renameSync(outputPath);
      } on FileSystemException {
        throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
      }
    } finally {
      _deleteQuietly(tmp);
    }

    final fontsLost = unavailableFonts(result.stdout);
    return [if (fontsLost.isNotEmpty) ConversionWarning(ConversionWarningKind.fontsSubstituted, items: fontsLost)];
  }

  /// rhwp는 암호가 필요하면 종료 코드 2와 "비밀번호" 안내를, 읽을 수 없으면 1을 낸다.
  static ConversionErrorKind _errorKind(HwpProcessResult r) {
    final text = r.stderr.toLowerCase();
    if (r.exitCode == 2 && (text.contains('비밀번호') || text.contains('password'))) {
      return ConversionErrorKind.passwordProtected;
    }
    return ConversionErrorKind.cannotRead;
  }

  static void _deleteQuietly(String path) {
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // 임시 파일을 못 지워도 변환 결과에는 영향이 없다.
    }
  }

  /// rhwp `--json` 출력에서 "공급하지 못한 글꼴" 이름을 뽑는다(`nativeFontSupply.unavailable`).
  /// 이 값은 문서에서 온 **신뢰할 수 없는 문자열**이므로 표시만 하고, 제어 문자를 지우고 길이·개수를 제한한다.
  /// 항목 뒤에 붙는 ": 사유" 문구는 떼고 같은 이름은 한 번만 센다. JSON이 아니거나 모양이 다르면 빈 목록이다.
  static List<String> unavailableFonts(String stdout) {
    try {
      final json = jsonDecode(stdout);
      final supply = json is Map ? json['nativeFontSupply'] : null;
      final list = supply is Map ? supply['unavailable'] : null;
      if (list is! List) return const [];
      final seen = <String>{};
      for (final item in list) {
        if (item is! String) continue;
        var name = item.split(': ').first.replaceAll(RegExp(r'[\x00-\x1f\x7f]'), '').trim();
        if (name.isEmpty) continue;
        if (name.length > _maxFontNameLength) name = '${name.substring(0, _maxFontNameLength)}…';
        seen.add(name);
        if (seen.length >= _maxFontNames) break;
      }
      return seen.toList();
    } on FormatException {
      return const [];
    }
  }

  static const _maxFontNameLength = 60;
  static const _maxFontNames = 100;
}
