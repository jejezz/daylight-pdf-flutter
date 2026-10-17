import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/viewer/annotation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakeDocument extends Fake implements PdfDocument {}

/// PDFium처럼 새 주석을 그 쪽 목록의 끝에 붙이고, 지우면 뒤 번호가 당겨지는 가짜 문서.
class _FakeBackend implements AnnotationBackend {
  final pages = <int, List<PdfAnnotationSpec>>{};
  final removed = <({int page, int index})>[];
  bool failNextRemove = false;

  @override
  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) async {
    for (final s in specs) {
      pages.putIfAbsent(s.pageIndex, () => []).add(s);
    }
  }

  @override
  Future<List<ReadAnnotation>> read(PdfDocument document) async => [
    for (final page in pages.keys.toList()..sort())
      for (var i = 0; i < pages[page]!.length; i++) ReadAnnotation(pageIndex: page, index: i, subtype: 5, contents: ''),
  ];

  @override
  Future<void> remove(PdfDocument document, int pageIndex, int index) async {
    if (failNextRemove) {
      failNextRemove = false;
      throw StateError('remove failed');
    }
    removed.add((page: pageIndex, index: index));
    pages[pageIndex]!.removeAt(index);
  }

  /// 쪽마다 남은 주석(그리는 순서대로 붙인 이름표 대신 색)을 읽기 쉽게.
  Map<int, List<int>> get colors => {
    for (final e in pages.entries) e.key: [for (final s in e.value) s.color],
  };
}

ShapeSpec _shape(int page, int color) =>
    ShapeSpec(pageIndex: page, color: color, kind: ShapeKind.square, box: (left: 0, bottom: 0, right: 10, top: 10));

void main() {
  late _FakeBackend backend;
  late AnnotationState state;
  final doc = _FakeDocument();

  setUp(() {
    backend = _FakeBackend();
    state = AnnotationState(backend);
  });

  test('nothing to undo at first, and undo then does nothing', () async {
    expect(state.canUndo, isFalse);
    await state.undo(doc);
    expect(backend.removed, isEmpty);
    expect(state.dirty, isFalse);
  });

  test('undo removes the most recent addition first, one step at a time', () async {
    await state.add(doc, [_shape(0, 1)]);
    await state.add(doc, [_shape(0, 2)]);
    await state.add(doc, [_shape(1, 3)]);
    expect(state.canUndo, isTrue);

    await state.undo(doc);
    expect(backend.colors, {
      0: [1, 2],
      1: [],
    });
    await state.undo(doc);
    expect(backend.colors, {
      0: [1],
      1: [],
    });
    await state.undo(doc);
    expect(backend.colors, {0: [], 1: []});
    expect(state.canUndo, isFalse);
    expect(state.items, isEmpty);
  });

  test('one user action that adds several annotations (a highlight over many lines) is undone together', () async {
    await state.add(doc, [_shape(0, 1)]);
    await state.add(doc, [_shape(0, 2), _shape(0, 3), _shape(1, 4)]);
    await state.undo(doc);
    expect(backend.colors, {
      0: [1],
      1: [],
    });
    // 뒤 번호부터 지웠으니 번호가 밀려 엉뚱한 주석을 지우는 일이 없다.
    expect(backend.removed, [(page: 1, index: 0), (page: 0, index: 2), (page: 0, index: 1)]);
  });

  test('deleting an earlier annotation from the list keeps undo pointing at the right one', () async {
    await state.add(doc, [_shape(0, 1)]); // 쪽 0의 0번
    await state.add(doc, [_shape(0, 2)]); // 쪽 0의 1번
    await state.add(doc, [_shape(0, 3)]); // 쪽 0의 2번

    await state.remove(doc, state.items.first); // 첫 주석을 목록에서 지움 → 2는 0번, 3은 1번이 된다
    expect(backend.colors, {
      0: [2, 3],
    });

    await state.undo(doc); // 마지막(3)을 지워야 한다
    expect(backend.colors, {
      0: [2],
    });
    await state.undo(doc);
    expect(backend.colors, {0: []});
    expect(state.canUndo, isFalse);
  });

  test('an annotation deleted from the list drops out of the undo history', () async {
    await state.add(doc, [_shape(0, 1)]);
    await state.add(doc, [_shape(0, 2)]);
    await state.remove(doc, state.items.last); // 마지막으로 단 주석을 목록에서 지움
    expect(backend.colors, {
      0: [1],
    });
    await state.undo(doc); // 이제 되돌릴 것은 처음 단 주석뿐
    expect(backend.colors, {0: []});
    expect(state.canUndo, isFalse);
  });

  test('undo marks the document as changed and flips the render revision', () async {
    await state.add(doc, [_shape(0, 1)]);
    state.markSaved();
    expect(state.dirty, isFalse);
    final before = state.revision;
    await state.undo(doc);
    expect(state.dirty, isTrue, reason: 'the saved file no longer matches the document');
    expect(state.revision, before + 1);
  });

  test('a failed undo clears the history instead of guessing, and reports the error', () async {
    await state.add(doc, [_shape(0, 1)]);
    await state.add(doc, [_shape(0, 2)]);
    backend.failNextRemove = true;
    await expectLater(state.undo(doc), throwsStateError);
    expect(state.canUndo, isFalse);
    expect(state.busy, isFalse, reason: 'state must not stay stuck busy');
  });
}
