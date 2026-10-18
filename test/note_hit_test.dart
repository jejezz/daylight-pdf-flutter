import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/viewer/note_hit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

ReadAnnotation note(int page, double l, double b, double r, double t, {int subtype = 1, String text = ''}) =>
    ReadAnnotation(
      pageIndex: page,
      index: 0,
      subtype: subtype,
      contents: text,
      rect: (left: l, bottom: b, right: r, top: t),
    );

void main() {
  final items = [note(0, 100, 100, 124, 124, text: 'a'), note(1, 100, 100, 124, 124, text: 'on page 1')];

  test('finds the note whose icon area contains the point, on that page only', () {
    expect(noteAt(items, 0, PdfPoint(110, 110))?.contents, 'a');
    expect(noteAt(items, 1, PdfPoint(110, 110))?.contents, 'on page 1');
  });

  test('points just outside the icon area are not a hit; the edges count as inside', () {
    expect(noteAt(items, 0, PdfPoint(99.9, 110)), isNull);
    expect(noteAt(items, 0, PdfPoint(124.1, 110)), isNull);
    expect(noteAt(items, 0, PdfPoint(110, 124.1)), isNull);
    expect(noteAt(items, 0, PdfPoint(110, 99.9)), isNull);
    expect(noteAt(items, 0, PdfPoint(100, 100))?.contents, 'a');
    expect(noteAt(items, 0, PdfPoint(124, 124))?.contents, 'a');
  });

  test('only notes count: other annotation types at the same spot are ignored', () {
    final mixed = [note(0, 0, 0, 200, 200, subtype: 5), note(0, 100, 100, 124, 124, text: 'note')];
    expect(noteAt(mixed, 0, PdfPoint(110, 110))?.contents, 'note');
    expect(noteAt([note(0, 0, 0, 200, 200, subtype: 9)], 0, PdfPoint(10, 10)), isNull);
  });

  test('when icons overlap, the one added last (drawn on top) wins', () {
    final overlap = [note(0, 100, 100, 124, 124, text: 'first'), note(0, 110, 110, 134, 134, text: 'second')];
    expect(noteAt(overlap, 0, PdfPoint(115, 115))?.contents, 'second');
    expect(noteAt(overlap, 0, PdfPoint(102, 102))?.contents, 'first');
  });

  test('an empty list or an unknown page gives nothing', () {
    expect(noteAt(const [], 0, PdfPoint(1, 1)), isNull);
    expect(noteAt(items, 7, PdfPoint(110, 110)), isNull);
  });
}
