import 'dart:io';

import 'package:path/path.dart' as p;
// ignore: implementation_imports
import 'package:pdfrx_engine/src/native/pdfrx_pdfium.dart' show pdfrxSetCharsetFallbackFont;

/// PDFium의 글꼴 문자 집합 번호: 한글.
const _hangulCharset = 129;

/// 글꼴을 PDF에 넣지 않은 한글 PDF(굴림·바탕 등을 이름으로만 가리키는 문서)를 그리기 위한 대체 글꼴.
///
/// pdfrx 사본(`third_party/pdfrx_engine`, DAYLIGHT_PATCH.md)은 PDFium이 CP949 바이트 이름으로 글꼴을 요청해도 받고,
/// 찾지 못한 한글 글꼴은 여기서 정한 **운영체제의 기본 한글 글꼴**로 대신 그린다. 이걸 안 하면 글자가 통째로 비고 글자 추출도 안 된다.
/// 한글 글꼴이 없는 시스템이면 사용자도 한글 문서를 읽을 수 없으므로 앱 글꼴로 되돌리지 않는다(다른 언어도 같은 이유로 다루지 않는다).
Future<void> installPdfFallbackFonts() async {
  final path = _systemHangulFont();
  if (path == null) return;
  await pdfrxSetCharsetFallbackFont(charset: _hangulCharset, filePath: path);
}

String? _systemHangulFont() {
  final windows = p.join(Platform.environment['WINDIR'] ?? r'C:\Windows', 'Fonts');
  final candidates = <String>[
    if (Platform.isWindows) ...[p.join(windows, 'malgun.ttf'), p.join(windows, 'gulim.ttc')],
    if (Platform.isMacOS) ...['/System/Library/Fonts/AppleSDGothicNeo.ttc', '/System/Library/Fonts/Supplemental/AppleGothic.ttf'],
    if (Platform.isLinux) ...[
      '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/noto-cjk/NotoSansCJK-Regular.ttc',
      '/usr/share/fonts/truetype/nanum/NanumGothic.ttf',
    ],
    if (Platform.isAndroid) ...['/system/fonts/NotoSansCJK-Regular.ttc', '/system/fonts/NotoSansKR-Regular.otf'],
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}
