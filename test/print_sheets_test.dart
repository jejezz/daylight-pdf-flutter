import 'package:daylight_pdf/print/print_layout.dart';
import 'package:daylight_pdf/print/print_options.dart';
import 'package:daylight_pdf/print/print_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a4 = PrintOptions(); // 595.28 x 841.89

  group('planSheet', () {
    test('2 portrait pages go side by side on a landscape sheet', () {
      final p = planSheet(2, 200, 300, a4);
      expect((p.cols, p.rows), (2, 1));
      expect(p.sheetWidth, closeTo(841.89, 1e-9));
      expect(p.cellWidth, closeTo(841.89 / 2, 1e-9));
      expect(p.cellHeight, closeTo(595.28, 1e-9));
    });

    test('2 landscape pages stack on a portrait sheet', () {
      final p = planSheet(2, 300, 200, a4);
      expect((p.cols, p.rows), (1, 2));
      expect(p.sheetWidth, closeTo(595.28, 1e-9));
      expect(p.cellHeight, closeTo(841.89 / 2, 1e-9));
    });

    test('4 and 9 per sheet keep a square grid, 6 follows the page shape', () {
      expect(planSheet(4, 200, 300, a4).perSheet, 4);
      final nine = planSheet(9, 200, 300, a4);
      expect((nine.cols, nine.rows), (3, 3));
      final six = planSheet(6, 200, 300, a4);
      expect(six.cols * six.rows, 6);
    });

    test('the margin is kept inside each cell, the cells fill the sheet', () {
      final p = planSheet(4, 200, 300, a4.copyWith(marginMm: 10));
      final m = 10 * 72 / 25.4;
      expect(p.marginPt, closeTo(m, 1e-9));
      expect(p.sheetWidth, closeTo(595.28, 1e-9));
      expect(p.cellWidth, closeTo(595.28 / 2, 1e-9));
      expect(p.cellHeight, closeTo(841.89 / 2, 1e-9));
    });

    test('a fixed orientation is kept when auto orientation is off', () {
      final p = planSheet(2, 200, 300, a4.copyWith(autoOrientation: false));
      expect(p.sheetWidth, closeTo(595.28, 1e-9)); // 세로 용지 그대로
      expect((p.cols, p.rows), (1, 2));
    });

    test('unsupported counts are rejected', () {
      expect(() => planSheet(3, 200, 300, a4), throwsArgumentError);
    });
  });

  group('bookletOrder', () {
    String show(List<int?> o) => o.map((e) => e == null ? '_' : '${e + 1}').join(' ');

    test('8 pages: the classic imposition', () {
      expect(show(bookletOrder(8)), '8 1 2 7 6 3 4 5');
    });

    test('4 pages are one sheet, front then back', () {
      expect(show(bookletOrder(4)), '4 1 2 3');
    });

    test('pages are padded with blanks to a multiple of 4', () {
      expect(show(bookletOrder(5)), '_ 1 2 _ _ 3 4 5');
      expect(bookletOrder(1), [null, 0, null, null]);
      expect(bookletOrder(0), isEmpty);
    });

    test('every page appears exactly once', () {
      for (final n in [1, 2, 3, 5, 9, 12, 13]) {
        final o = bookletOrder(n).whereType<int>().toList()..sort();
        expect(o, [for (var i = 0; i < n; i++) i], reason: '$n pages');
        expect(bookletOrder(n).length % 4, 0);
      }
    });
  });

  group('visibleToUser', () {
    test('maps the visible page back to page coordinates for every rotation', () {
      const box = (left: 0.0, bottom: 0.0, right: 100.0, top: 200.0);
      for (final rot in [0, 90, 180, 270]) {
        final m = visibleToUser(box, rot);
        // 눈에 보이는 쪽의 네 모서리를 쪽 좌표로 보내면, 쪽 좌표를 다시 화면으로 보냈을 때 제자리다
        final w = rot % 180 == 0 ? 100.0 : 200.0, h = rot % 180 == 0 ? 200.0 : 100.0;
        for (final (vx, vy) in [(0.0, 0.0), (w, 0.0), (0.0, h), (w, h), (w / 3, h / 4)]) {
          final ux = m.a * vx + m.c * vy + m.e, uy = m.b * vx + m.d * vy + m.f;
          final back = visiblePoint(box, rot, ux, uy);
          expect(back.x, closeTo(vx, 1e-6), reason: 'rot $rot');
          expect(back.y, closeTo(vy, 1e-6), reason: 'rot $rot');
        }
      }
    });
  });
}
