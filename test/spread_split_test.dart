import 'package:daylight_pdf/pages/spread_split.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const box = (left: 0.0, bottom: 0.0, right: 200.0, top: 100.0);

  test('rotation 0: left/right halves split the width in the middle', () {
    expect(spreadHalfBox(box, 0, SpreadHalf.left), (left: 0.0, bottom: 0.0, right: 100.0, top: 100.0));
    expect(spreadHalfBox(box, 0, SpreadHalf.right), (left: 100.0, bottom: 0.0, right: 200.0, top: 100.0));
  });

  test('a box that does not start at the origin is split in its own middle', () {
    const offset = (left: 10.0, bottom: 20.0, right: 110.0, top: 70.0);
    expect(spreadHalfBox(offset, 0, SpreadHalf.right), (left: 60.0, bottom: 20.0, right: 110.0, top: 70.0));
  });

  test('rotated pages: the visible left side maps to bottom / right / top', () {
    expect(spreadHalfBox(box, 90, SpreadHalf.left), (left: 0.0, bottom: 0.0, right: 200.0, top: 50.0));
    expect(spreadHalfBox(box, 90, SpreadHalf.right), (left: 0.0, bottom: 50.0, right: 200.0, top: 100.0));
    expect(spreadHalfBox(box, 180, SpreadHalf.left), (left: 100.0, bottom: 0.0, right: 200.0, top: 100.0));
    expect(spreadHalfBox(box, 270, SpreadHalf.left), (left: 0.0, bottom: 50.0, right: 200.0, top: 100.0));
    expect(spreadHalfBox(box, 270, SpreadHalf.right), (left: 0.0, bottom: 0.0, right: 200.0, top: 50.0));
  });

  test('plan splits chosen pages in place and keeps the others', () {
    expect(planSpreadSplit(3, {2}), [(1, null), (2, SpreadHalf.left), (2, SpreadHalf.right), (3, null)]);
    expect(planSpreadSplit(2, {1, 2}, rightFirst: true), [
      (1, SpreadHalf.right),
      (1, SpreadHalf.left),
      (2, SpreadHalf.right),
      (2, SpreadHalf.left),
    ]);
  });
}
