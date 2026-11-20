import 'dart:io';

import 'package:daylight_pdf/home/open_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('명령줄 인자에서 실제로 있고 열 수 있는 파일만 고른다', () {
    final dir = Directory.systemTemp.createTempSync('args_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    File touch(String name) => File('${dir.path}/$name')..writeAsBytesSync([1]);
    final pdf = touch('문서 A.PDF');
    final png = touch('사진.png');
    final svg = touch('그림.SVG');
    final ai = touch('로고.ai');
    final hwp = touch('보고서.hwp');
    final txt = touch('a.txt');

    expect(filesFromArguments([]), isEmpty);
    expect(filesFromArguments([txt.path]), isEmpty);
    expect(filesFromArguments(['${dir.path}/없음.pdf']), isEmpty);
    expect(filesFromArguments(['--new-window', txt.path, pdf.path]), [pdf.path]);
    expect(filesFromArguments([png.path, svg.path, ai.path, hwp.path]), [png.path, svg.path, ai.path, hwp.path]);
  });

  test('열 수 있는 형식', () {
    for (final name in ['a.pdf', 'a.ai', 'a.svg', 'a.png', 'a.JPG', 'a.jpeg', 'a.bmp', 'a.gif', 'a.webp', 'a.tif', 'a.tiff', 'a.hwp', 'a.HWPX', 'a.hml']) {
      expect(isOpenableFile(name), isTrue, reason: name);
    }
    for (final name in ['a.heic', 'a.txt', 'a.docx', 'pdf']) {
      expect(isOpenableFile(name), isFalse, reason: name);
    }
  });

  test('변환 화면으로 여는 확장자에 HWP 계열이 들어 있다', () {
    expect(convertExtensions, containsAll(['hwp', 'hwpx', 'hml']));
  });
}
