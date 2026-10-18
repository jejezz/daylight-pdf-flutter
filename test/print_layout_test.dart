import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/print/print_layout.dart';
import 'package:daylight_pdf/print/print_options.dart';
import 'package:flutter_test/flutter_test.dart';

(double, double) apply(Matrix6 m, double x, double y) => (m.a * x + m.c * y + m.e, m.b * x + m.d * y + m.f);

void expectPoint((double, double) got, double x, double y) {
  expect(got.$1, closeTo(x, 1e-6));
  expect(got.$2, closeTo(y, 1e-6));
}

void main() {
  inverseTests();
  group('selectPrintPages', () {
    test('everything by default, as zero-based indices', () {
      expect(selectPrintPages(4, const PrintOptions()), [0, 1, 2, 3]);
    });
    test('range, odd/even and reverse apply in that order', () {
      expect(selectPrintPages(10, const PrintOptions(range: '2-7')), [1, 2, 3, 4, 5, 6]);
      expect(selectPrintPages(10, const PrintOptions(range: '2-7', parity: PrintParity.odd)), [2, 4, 6]);
      expect(selectPrintPages(10, const PrintOptions(range: '2-7', parity: PrintParity.even, reverse: true)), [
        5,
        3,
        1,
      ]);
      expect(selectPrintPages(5, const PrintOptions(range: '1, 3, 3')), [0, 2, 2]);
    });
    test('"current" means only the page being viewed', () {
      expect(selectPrintPages(9, const PrintOptions(range: 'current'), currentPage: 4), [3]);
    });
    test('bad ranges and empty selections are invalid', () {
      for (final o in const [
        PrintOptions(range: '0-3'),
        PrintOptions(range: '9'),
        PrintOptions(range: 'x'),
        PrintOptions(range: '2', parity: PrintParity.odd),
      ]) {
        expect(
          () => selectPrintPages(5, o),
          throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.invalidPageRange)),
        );
      }
    });
  });

  group('placePage', () {
    const a4 = PrintOptions(); // 595.28 x 841.89
    test('a page already A4 maps to itself with no margin', () {
      final r = placePage((left: 0, bottom: 0, right: 595.28, top: 841.89), 0, a4);
      expectPoint(apply(r.matrix, 0, 0), 0, 0);
      expectPoint(apply(r.matrix, 595.28, 841.89), 595.28, 841.89);
    });

    test('fit enlarges a small page and centres it', () {
      final r = placePage((left: 0, bottom: 0, right: 100, top: 100), 0, a4);
      expect(r.paperWidth, closeTo(595.28, 1e-9));
      expectPoint(apply(r.matrix, 0, 0), 0, (841.89 - 595.28) / 2);
      expectPoint(apply(r.matrix, 100, 100), 595.28, (841.89 + 595.28) / 2);
    });

    test('shrink leaves a small page alone, actual does not shrink a big one', () {
      final small = (left: 0.0, bottom: 0.0, right: 100.0, top: 100.0);
      final s = placePage(small, 0, a4.copyWith(scale: PrintScale.shrink));
      expectPoint(apply(s.matrix, 100, 0), (595.28 + 100) / 2, (841.89 - 100) / 2);
      final big = (left: 0.0, bottom: 0.0, right: 2000.0, top: 3000.0);
      expect(placePage(big, 0, a4.copyWith(scale: PrintScale.shrink)).matrix.a, lessThan(1));
      expect(placePage(big, 0, a4.copyWith(scale: PrintScale.actual)).matrix.a, 1);
    });

    test('margins keep the page inside, and the clip is the inner area', () {
      final o = a4.copyWith(marginMm: 10); // 28.346 pt
      final r = placePage((left: 0, bottom: 0, right: 595.28, top: 841.89), 0, o);
      final m = 10 * 72 / 25.4;
      expect(r.clip.left, closeTo(m, 1e-9));
      expect(r.clip.top, closeTo(841.89 - m, 1e-9));
      final lo = apply(r.matrix, 0, 0), hi = apply(r.matrix, 595.28, 841.89);
      expect(lo.$1, closeTo(m, 1e-6)); // 가로가 꽉 찬다
      expect(hi.$1, closeTo(595.28 - m, 1e-6));
      expect(lo.$2, greaterThanOrEqualTo(m - 1e-6)); // 세로는 여백 안쪽에서 가운데
      expect(hi.$2, lessThanOrEqualTo(841.89 - m + 1e-6));
      expect((lo.$2 - m) - (841.89 - m - hi.$2), closeTo(0, 1e-6));
    });

    test('a landscape page turns the paper when auto orientation is on', () {
      final land = (left: 0.0, bottom: 0.0, right: 841.89, top: 595.28);
      final r = placePage(land, 0, a4);
      expect(r.paperWidth, closeTo(841.89, 1e-9));
      expect(r.paperHeight, closeTo(595.28, 1e-9));
      final fixed = placePage(land, 0, a4.copyWith(autoOrientation: false));
      expect(fixed.paperWidth, closeTo(595.28, 1e-9));
    });

    test('rotation is folded into the matrix: the corners land where the viewer shows them', () {
      // 100 x 200 쪽의 내용 좌표에서 왼쪽 아래(0,0)와 오른쪽 위(100,200)가 회전 후 어디에 보이는가
      const box = (left: 0.0, bottom: 0.0, right: 100.0, top: 200.0);
      const o = PrintOptions(scale: PrintScale.actual, paperWidth: 300, paperHeight: 300, autoOrientation: false);
      // 시계 방향 90°: 눈에 보이는 쪽은 200 x 100, 내용의 왼쪽 아래는 보이는 쪽의 왼쪽 위로 간다.
      var r = placePage(box, 90, o);
      var tx = (300 - 200) / 2, ty = (300 - 100) / 2;
      expectPoint(apply(r.matrix, 0, 0), tx + 0, ty + 100);
      expectPoint(apply(r.matrix, 100, 200), tx + 200, ty + 0);
      r = placePage(box, 180, o);
      tx = (300 - 100) / 2;
      ty = (300 - 200) / 2;
      expectPoint(apply(r.matrix, 0, 0), tx + 100, ty + 200);
      expectPoint(apply(r.matrix, 100, 200), tx, ty);
      r = placePage(box, 270, o);
      tx = (300 - 200) / 2;
      ty = (300 - 100) / 2;
      expectPoint(apply(r.matrix, 0, 0), tx + 200, ty + 0);
      expectPoint(apply(r.matrix, 100, 200), tx + 0, ty + 100);
    });

    test('an offset page box is respected', () {
      const box = (left: 50.0, bottom: 70.0, right: 150.0, top: 170.0);
      final r = placePage(box, 0, const PrintOptions(scale: PrintScale.actual, paperWidth: 100, paperHeight: 100));
      expectPoint(apply(r.matrix, 50, 70), 0, 0);
      expectPoint(apply(r.matrix, 150, 170), 100, 100);
    });
  });
}

void inverseTests() {
  group('box helpers', () {
    test('transformBox is where the page lands on the paper, for every rotation', () {
      const box = (left: 10.0, bottom: 20.0, right: 110.0, top: 220.0);
      const o = PrintOptions(scale: PrintScale.actual, paperWidth: 500, paperHeight: 500, autoOrientation: false);
      for (final rot in [0, 90, 180, 270]) {
        final r = placePage(box, rot, o);
        final landed = transformBox(r.matrix, box);
        final w = rot % 180 == 0 ? 100.0 : 200.0, h = rot % 180 == 0 ? 200.0 : 100.0;
        expect(landed.right - landed.left, closeTo(w, 1e-6), reason: 'rot $rot');
        expect(landed.top - landed.bottom, closeTo(h, 1e-6), reason: 'rot $rot');
        expect((landed.left + landed.right) / 2, closeTo(250, 1e-6), reason: 'rot $rot');
        expect((landed.bottom + landed.top) / 2, closeTo(250, 1e-6), reason: 'rot $rot');
      }
    });
    test('intersectBoxes', () {
      final i = intersectBoxes((left: 0, bottom: 0, right: 10, top: 10), (left: 5, bottom: -5, right: 20, top: 4));
      expect((i.left, i.bottom, i.right, i.top), (5.0, 0.0, 10.0, 4.0));
    });
  });
}
