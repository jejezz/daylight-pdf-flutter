import 'package:daylight_pdf/viewer/text_boxes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  // PdfRect(left, top, right, bottom): 위쪽이 큰 값.
  const a = PdfRect(10, 100, 20, 90);
  const b = PdfRect(20, 101, 30, 91); // 같은 줄 (거의 같은 높이)
  const c = PdfRect(10, 80, 20, 70); // 다음 줄
  const d = PdfRect(20, 80, 30, 70);

  test('characters on one line merge into one box, a new line starts a new box', () {
    final boxes = lineBoxes([a, b, c, d], 0, 4);
    expect(boxes, [
      (left: 10.0, bottom: 90.0, right: 30.0, top: 101.0),
      (left: 10.0, bottom: 70.0, right: 30.0, top: 80.0),
    ]);
  });

  test('only the selected range is used', () {
    expect(lineBoxes([a, b, c, d], 1, 3), [
      (left: 20.0, bottom: 91.0, right: 30.0, top: 101.0),
      (left: 10.0, bottom: 70.0, right: 20.0, top: 80.0),
    ]);
  });

  test('empty boxes (spaces) are skipped and ranges beyond the text are clamped', () {
    const space = PdfRect(20, 100, 20, 90);
    expect(lineBoxes([a, space, b], 0, 3), [(left: 10.0, bottom: 90.0, right: 30.0, top: 101.0)]);
    expect(lineBoxes([a], 0, 99), [(left: 10.0, bottom: 90.0, right: 20.0, top: 100.0)]);
    expect(lineBoxes([a], 1, 1), isEmpty);
    expect(lineBoxes(const [], 0, 0), isEmpty);
  });

  test('a tall glyph does not merge two separate lines', () {
    const tall = PdfRect(10, 95, 20, 75); // 두 줄에 걸치지만 각 줄과 절반 미만 겹침
    expect(lineBoxes([a, tall], 0, 2).length, 2);
  });
}
