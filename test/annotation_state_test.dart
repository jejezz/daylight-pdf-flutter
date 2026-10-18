import 'package:daylight_pdf/engine/annotations/annotation_specs.dart';
import 'package:daylight_pdf/engine/annotations/pdfium_annotations.dart';
import 'package:daylight_pdf/viewer/annotation_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

class _FakeDocument extends Fake implements PdfDocument {}

/// PDFium처럼 새 주석을 그 쪽 목록의 끝에 붙이고, 지우면 뒤 번호가 당겨지는 가짜 문서.
class _Entry {
  _Entry(this.spec) : contents = spec is NoteSpec ? spec.text : '';
  final PdfAnnotationSpec spec;
  String contents;
}

class _FakeBackend implements AnnotationBackend {
  final docPages = <int, List<_Entry>>{};
  final readRequests = <Set<int>?>[];
  final removed = <({int page, int index})>[];
  bool failNextRemove = false;

  @override
  Future<void> add(PdfDocument document, List<PdfAnnotationSpec> specs) async {
    for (final s in specs) {
      docPages.putIfAbsent(s.pageIndex, () => []).add(_Entry(s));
    }
  }

  @override
  Future<List<ReadAnnotation>> read(PdfDocument document, {Set<int>? pages}) async {
    readRequests.add(pages);
    return [
      for (final page in docPages.keys.toList()..sort())
        if (pages == null || pages.contains(page))
          for (var i = 0; i < docPages[page]!.length; i++)
            ReadAnnotation(pageIndex: page, index: i, subtype: 5, contents: docPages[page]![i].contents),
    ];
  }

  @override
  Future<void> remove(PdfDocument document, int pageIndex, int index) async {
    if (failNextRemove) {
      failNextRemove = false;
      throw StateError('remove failed');
    }
    removed.add((page: pageIndex, index: index));
    docPages[pageIndex]!.removeAt(index);
  }

  @override
  Future<void> setContents(PdfDocument document, int pageIndex, int index, String text) async {
    docPages[pageIndex]![index].contents = text;
  }

  /// 쪽마다 남은 주석(그리는 순서대로 붙인 이름표 대신 색)을 읽기 쉽게.
  Map<int, List<int>> get colors => {
    for (final e in docPages.entries) e.key: [for (final x in e.value) x.spec.color],
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

  test('after a change only the touched pages are read again, and the list stays in order', () async {
    await state.refresh(doc);
    await state.add(doc, [_shape(2, 1), _shape(0, 1)]);
    await state.add(doc, [_shape(0, 2)]);
    expect(backend.readRequests, [null, {2, 0}, {0}]);
    expect(state.items.map((a) => (a.pageIndex, a.index)), [(0, 0), (0, 1), (2, 0)]);
    await state.undo(doc);
    expect(backend.readRequests.last, {0});
    expect(state.items.map((a) => (a.pageIndex, a.index)), [(0, 0), (2, 0)]);
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

  group('editNote', () {
    NoteSpec note(int page, int color, String text) => NoteSpec(pageIndex: page, color: color, x: 0, y: 0, text: text);

    test('changes the text of that note only, and marks the document as changed', () async {
      await state.add(doc, [note(0, 1, '첫 메모'), note(0, 2, '둘째 메모')]);
      state.markSaved();
      expect(state.dirty, isFalse);

      await state.editNote(doc, state.items[1], '고친 메모');
      expect(state.items.map((a) => a.contents), ['첫 메모', '고친 메모']);
      expect(state.dirty, isTrue);
    });

    test('is not an undo step: undo still removes the last added annotation', () async {
      await state.add(doc, [note(0, 1, 'a')]);
      await state.add(doc, [note(0, 2, 'b')]);
      await state.editNote(doc, state.items.first, '고침');

      await state.undo(doc); // 마지막으로 단 b가 지워진다 (고치기는 기록에 없다)
      expect(state.items.map((a) => a.contents), ['고침']);
      await state.undo(doc);
      expect(state.items, isEmpty);
      expect(state.canUndo, isFalse);
    });

    test('works on a note whose index shifted after a deletion', () async {
      await state.add(doc, [note(0, 1, 'a'), note(0, 2, 'b'), note(0, 3, 'c')]);
      await state.remove(doc, state.items.first); // a를 지움 → b가 0번, c가 1번
      await state.editNote(doc, state.items.last, '고친 c');
      expect(state.items.map((a) => a.contents), ['b', '고친 c']);
    });
  });

  group('pen width and finger/stylus', () {
    test('width defaults to medium, can be changed and stays inside the choices', () {
      expect(state.strokeWidth, AnnotationState.strokeWidths[1]);
      state.setWidthIndex(2);
      expect(state.strokeWidth, AnnotationState.strokeWidths[2]);
      state.setWidthIndex(99);
      expect(state.widthIndex, AnnotationState.strokeWidths.length - 1);
      state.setWidthIndex(-3);
      expect(state.widthIndex, 0);
      expect(AnnotationState.strokeWidths, orderedEquals([...AnnotationState.strokeWidths]..sort()));
    });

    test('fingers draw until a stylus is seen, then only the pen draws (until turned back on)', () {
      expect(state.fingerDraws, isTrue);
      var notified = 0;
      state.addListener(() => notified++);
      state.noteStylus();
      expect(state.fingerDraws, isFalse);
      expect(notified, 1);
      state.noteStylus(); // 두 번째부터는 아무 일도 없다
      expect(notified, 1);
      state.setFingerDraws(true); // 사용자가 다시 켰다
      state.noteStylus(); // 이미 본 펜이라 다시 끄지 않는다
      expect(state.fingerDraws, isTrue);
    });
  });
}
