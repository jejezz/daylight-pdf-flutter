import 'dart:io';

import 'package:daylight_pdf/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('명령줄 인자에서 실제로 있는 PDF만 고른다', () {
    final dir = Directory.systemTemp.createTempSync('args_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final pdf = File('${dir.path}/문서 A.PDF')..writeAsBytesSync([1]);
    final txt = File('${dir.path}/a.txt')..writeAsBytesSync([1]);

    expect(pdfFromArguments([]), isNull);
    expect(pdfFromArguments([txt.path]), isNull);
    expect(pdfFromArguments(['${dir.path}/없음.pdf']), isNull);
    expect(pdfFromArguments(['--flag', txt.path, pdf.path]), pdf.path);
  });
}
