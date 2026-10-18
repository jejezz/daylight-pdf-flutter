/// PDF 사용자 공간(원점이 왼쪽 아래, 단위 pt)의 상자.
typedef PdfBox = ({double left, double bottom, double right, double top});

/// 색은 0xAARRGGBB. 알파는 주석의 불투명도(`/CA`)가 된다.
sealed class PdfAnnotationSpec {
  const PdfAnnotationSpec({required this.pageIndex, required this.color});

  /// 0부터 센 쪽 위치.
  final int pageIndex;
  final int color;
}

/// 글자 위에 칠하는 형광펜. [boxes]마다 한 덩어리(여러 줄이면 줄마다 하나).
class HighlightSpec extends PdfAnnotationSpec {
  const HighlightSpec({required super.pageIndex, required super.color, required this.boxes});
  final List<PdfBox> boxes;
}

/// 글자 밑줄.
class UnderlineSpec extends PdfAnnotationSpec {
  const UnderlineSpec({required super.pageIndex, required super.color, required this.boxes});
  final List<PdfBox> boxes;
}

/// 스티커 메모(팝업 노트). [x], [y]는 아이콘 왼쪽 아래 위치.
///
/// [iconSvg]를 주면 그 SVG를 저장한 PDF 안의 메모 모양으로 넣어, 다른 뷰어에서도 같은 아이콘으로 보인다
/// (`svgToAppearance` 참고, 단색 도형 위주·그라디언트 근사). 주지 않거나 변환할 수 없으면 뷰어의 기본 아이콘이 쓰인다.
/// SVG 안의 `currentColor`는 [color]로 칠해진다.
class NoteSpec extends PdfAnnotationSpec {
  const NoteSpec({
    required super.pageIndex,
    required super.color,
    required this.x,
    required this.y,
    required this.text,
    this.iconSvg,
  });

  /// 메모 아이콘의 한 변 (pt).
  static const iconSize = 24.0;

  final double x;
  final double y;
  final String text;
  final String? iconSvg;
}

/// 손글씨. [strokes]마다 이어진 선 하나.
class InkSpec extends PdfAnnotationSpec {
  const InkSpec({required super.pageIndex, required super.color, required this.strokes, this.width = 2});
  final List<List<({double x, double y})>> strokes;
  final double width;
}

enum ShapeKind { square, circle }

/// 사각형·원 윤곽선.
class ShapeSpec extends PdfAnnotationSpec {
  const ShapeSpec({
    required super.pageIndex,
    required super.color,
    required this.kind,
    required this.box,
    this.width = 2,
  });
  final ShapeKind kind;
  final PdfBox box;
  final double width;
}
