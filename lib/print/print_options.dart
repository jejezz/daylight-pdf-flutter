import '../convert/conversion_error.dart';
import '../pages/page_ranges.dart';

/// 어느 쪽을 찍을지: 전체, 홀수쪽만, 짝수쪽만.
enum PrintParity { all, odd, even }

/// 쪽을 용지에 맞추는 방법.
enum PrintScale {
  /// 용지(여백 안쪽)에 꽉 차게: 크면 줄이고 작으면 키운다.
  fit,

  /// 큰 쪽만 줄이고 작은 쪽은 원래 크기로.
  shrink,

  /// 원래 크기 그대로 (용지보다 크면 잘린다).
  actual,
}

/// 출력 설정. 프린터·매수·양면·컬러·용지함 같은 프린터 설정은 운영체제 인쇄 창이 맡고,
/// 여기서는 PDF를 찍기 전에 가공하는 설정만 둔다.
class PrintOptions {
  const PrintOptions({
    this.range = '',
    this.parity = PrintParity.all,
    this.reverse = false,
    this.includeAnnotations = true,
    this.scale = PrintScale.fit,
    this.marginMm = 0,
    this.paperWidth = 595.28,
    this.paperHeight = 841.89,
    this.autoOrientation = true,
  });

  /// `1-3, 5, 8-` 형식 (비우면 전체). 쉼표로 이은 순서와 중복을 그대로 따른다.
  final String range;
  final PrintParity parity;
  final bool reverse;

  /// 메모·형광펜 같은 주석을 찍을지.
  final bool includeAnnotations;
  final PrintScale scale;

  /// 사방 여백(mm).
  final double marginMm;

  /// 세로 방향 용지 크기(pt). 기본은 A4.
  final double paperWidth;
  final double paperHeight;

  /// 가로로 긴 쪽은 용지를 가로로 돌려 쓴다.
  final bool autoOrientation;

  PrintOptions copyWith({
    String? range,
    PrintParity? parity,
    bool? reverse,
    bool? includeAnnotations,
    PrintScale? scale,
    double? marginMm,
    double? paperWidth,
    double? paperHeight,
    bool? autoOrientation,
  }) => PrintOptions(
    range: range ?? this.range,
    parity: parity ?? this.parity,
    reverse: reverse ?? this.reverse,
    includeAnnotations: includeAnnotations ?? this.includeAnnotations,
    scale: scale ?? this.scale,
    marginMm: marginMm ?? this.marginMm,
    paperWidth: paperWidth ?? this.paperWidth,
    paperHeight: paperHeight ?? this.paperHeight,
    autoOrientation: autoOrientation ?? this.autoOrientation,
  );

  double get marginPt => marginMm * 72 / 25.4;
}

/// 찍을 쪽 번호(0부터)를 순서대로 고른다. 범위 → 홀짝 → 역순 순서로 적용한다.
/// [currentPage]는 1부터이며 범위 칸에 `current`라고 쓰면 그 쪽만 뜻한다.
/// 범위가 틀리면 [ConversionErrorKind.invalidPageRange], 고른 쪽이 하나도 없으면 같은 오류를 던진다.
List<int> selectPrintPages(int pageCount, PrintOptions options, {int currentPage = 1}) {
  final text = options.range.trim();
  var pages = text.isEmpty
      ? [for (var n = 1; n <= pageCount; n++) n]
      : text.toLowerCase() == 'current'
      ? [currentPage]
      : parsePageList(text, pageCount);
  pages = switch (options.parity) {
    PrintParity.all => pages,
    PrintParity.odd => pages.where((n) => n.isOdd).toList(),
    PrintParity.even => pages.where((n) => n.isEven).toList(),
  };
  if (options.reverse) pages = pages.reversed.toList();
  if (pages.isEmpty) throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: text);
  return [for (final n in pages) n - 1];
}
