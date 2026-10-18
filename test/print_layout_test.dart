import 'dart:math' as math;

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
  boxTests();
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
    /// 쪽 좌표 (x, y)가 새 쪽 상자에서 화면의 어디에 놓이는지.
    ({double x, double y}) landed(PageBox box, int rot, PlacedPage r, double x, double y) {
      final (nx, ny) = apply(r.matrix, x, y);
      final newBox = (left: 0.0, bottom: 0.0, right: r.boxWidth, top: r.boxHeight);
      return visiblePoint(newBox, rot, nx, ny);
    }

    test('a page already A4 maps to itself with no margin', () {
      const box = (left: 0.0, bottom: 0.0, right: 595.28, top: 841.89);
      final r = placePage(box, 0, a4);
      final p0 = landed(box, 0, r, 0, 0), p1 = landed(box, 0, r, 595.28, 841.89);
      expect(p0.x, closeTo(0, 1e-6));
      expect(p0.y, closeTo(0, 1e-6));
      expect(p1.x, closeTo(595.28, 1e-6));
      expect(p1.y, closeTo(841.89, 1e-6));
    });

    test('fit enlarges a small page and centres it', () {
      const box = (left: 0.0, bottom: 0.0, right: 100.0, top: 100.0);
      final r = placePage(box, 0, a4);
      expect(r.paperWidth, closeTo(595.28, 1e-9));
      final p0 = landed(box, 0, r, 0, 0), p1 = landed(box, 0, r, 100, 100);
      expect(p0.x, closeTo(0, 1e-6));
      expect(p0.y, closeTo((841.89 - 595.28) / 2, 1e-6));
      expect(p1.x, closeTo(595.28, 1e-6));
      expect(p1.y, closeTo((841.89 + 595.28) / 2, 1e-6));
    });

    test('shrink leaves a small page alone, actual does not shrink a big one', () {
      const small = (left: 0.0, bottom: 0.0, right: 100.0, top: 100.0);
      final s = placePage(small, 0, a4.copyWith(scale: PrintScale.shrink));
      expect(landed(small, 0, s, 100, 0).x, closeTo((595.28 + 100) / 2, 1e-6));
      const big = (left: 0.0, bottom: 0.0, right: 2000.0, top: 3000.0);
      expect(placePage(big, 0, a4.copyWith(scale: PrintScale.shrink)).matrix.a, lessThan(1));
      expect(placePage(big, 0, a4.copyWith(scale: PrintScale.actual)).matrix.a, 1);
    });

    test('margins keep the page inside, and the clip is the inner area', () {
      const box = (left: 0.0, bottom: 0.0, right: 595.28, top: 841.89);
      final r = placePage(box, 0, a4.copyWith(marginMm: 10));
      final m = 10 * 72 / 25.4;
      expect(r.clip.left, closeTo(m, 1e-9));
      expect(r.clip.top, closeTo(841.89 - m, 1e-9));
      final lo = landed(box, 0, r, 0, 0), hi = landed(box, 0, r, 595.28, 841.89);
      expect(lo.x, closeTo(m, 1e-6)); // 가로가 꽉 찬다
      expect(hi.x, closeTo(595.28 - m, 1e-6));
      expect(lo.y, greaterThanOrEqualTo(m - 1e-6)); // 세로는 여백 안쪽에서 가운데
      expect(hi.y, lessThanOrEqualTo(841.89 - m + 1e-6));
      expect((lo.y - m) - (841.89 - m - hi.y), closeTo(0, 1e-6));
    });

    test('a landscape page turns the paper when auto orientation is on', () {
      const land = (left: 0.0, bottom: 0.0, right: 841.89, top: 595.28);
      final r = placePage(land, 0, a4);
      expect(r.paperWidth, closeTo(841.89, 1e-9));
      expect(r.paperHeight, closeTo(595.28, 1e-9));
      expect(placePage(land, 0, a4.copyWith(autoOrientation: false)).paperWidth, closeTo(595.28, 1e-9));
    });

    test('page rotation is kept: boxes swap for 90/270 and corners land where the viewer shows them', () {
      // 100 x 200 쪽. 시계 방향 90°면 눈에 보이는 쪽은 200 x 100.
      const box = (left: 0.0, bottom: 0.0, right: 100.0, top: 200.0);
      const o = PrintOptions(scale: PrintScale.actual, paperWidth: 300, paperHeight: 300, autoOrientation: false);
      void expectLanded(int rot, (double, double) from, (double, double) to) {
        final r = placePage(box, rot, o);
        final p = landed(box, rot, r, from.$1, from.$2);
        expect(p.x, closeTo(to.$1, 1e-6), reason: 'rot $rot x');
        expect(p.y, closeTo(to.$2, 1e-6), reason: 'rot $rot y');
      }

      expect(placePage(box, 90, o).boxWidth, 300);
      expect(placePage(box, 0, o).boxHeight, 300);
      // 90°: 내용의 왼쪽 아래는 보이는 쪽의 왼쪽 위로, 오른쪽 위는 오른쪽 아래로
      expectLanded(90, (0, 0), ((300 - 200) / 2 + 0, (300 - 100) / 2 + 100));
      expectLanded(90, (100, 200), ((300 - 200) / 2 + 200, (300 - 100) / 2 + 0));
      expectLanded(180, (0, 0), ((300 - 100) / 2 + 100, (300 - 200) / 2 + 200));
      expectLanded(180, (100, 200), ((300 - 100) / 2, (300 - 200) / 2));
      expectLanded(270, (0, 0), ((300 - 200) / 2 + 200, (300 - 100) / 2 + 0));
      expectLanded(270, (100, 200), ((300 - 200) / 2 + 0, (300 - 100) / 2 + 100));
      expectLanded(0, (0, 0), ((300 - 100) / 2, (300 - 200) / 2));
    });

    test('the clip, mapped to the screen, is the inner area for every rotation', () {
      const box = (left: 10.0, bottom: 20.0, right: 110.0, top: 220.0);
      for (final rot in [0, 90, 180, 270]) {
        final o = const PrintOptions(marginMm: 5, paperWidth: 400, paperHeight: 500, autoOrientation: false);
        final r = placePage(box, rot, o);
        final newBox = (left: 0.0, bottom: 0.0, right: r.boxWidth, top: r.boxHeight);
        final a = visiblePoint(newBox, rot, r.clip.left, r.clip.bottom),
            b = visiblePoint(newBox, rot, r.clip.right, r.clip.top);
        final m = 5 * 72 / 25.4;
        expect(math.min(a.x, b.x), closeTo(m, 1e-6), reason: 'rot $rot');
        expect(math.max(a.x, b.x), closeTo(400 - m, 1e-6), reason: 'rot $rot');
        expect(math.min(a.y, b.y), closeTo(m, 1e-6), reason: 'rot $rot');
        expect(math.max(a.y, b.y), closeTo(500 - m, 1e-6), reason: 'rot $rot');
      }
    });

    test('an offset page box is respected', () {
      const box = (left: 50.0, bottom: 70.0, right: 150.0, top: 170.0);
      final r = placePage(box, 0, const PrintOptions(scale: PrintScale.actual, paperWidth: 100, paperHeight: 100));
      final p0 = landed(box, 0, r, 50, 70), p1 = landed(box, 0, r, 150, 170);
      expect(p0.x, closeTo(0, 1e-6));
      expect(p0.y, closeTo(0, 1e-6));
      expect(p1.x, closeTo(100, 1e-6));
      expect(p1.y, closeTo(100, 1e-6));
    });
  });
}

void boxTests() {
  test('transformBox and intersectBoxes', () {
    final t = transformBox((a: 2.0, b: 0.0, c: 0.0, d: 2.0, e: 10.0, f: 20.0), (left: 0, bottom: 0, right: 5, top: 10));
    expect((t.left, t.bottom, t.right, t.top), (10.0, 20.0, 20.0, 40.0));
    final i = intersectBoxes((left: 0, bottom: 0, right: 10, top: 10), (left: 5, bottom: -5, right: 20, top: 4));
    expect((i.left, i.bottom, i.right, i.top), (5.0, 0.0, 10.0, 4.0));
  });
}
