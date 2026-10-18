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

/// 쪽 번호를 찍을 자리.
enum PrintPageNumbers { none, bottomCenter, bottomRight, bottomLeft, topRight }

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
    this.perSheet = 1,
    this.booklet = false,
    this.sheetBorder = false,
    this.pageNumbers = PrintPageNumbers.none,
    this.pageNumberTotal = false,
    this.watermark = '',
    this.grayscale = false,
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

  /// 한 장에 모을 쪽 수 (1, 2, 4, 6, 9). 소책자면 무시한다.
  final int perSheet;

  /// 소책자: 접어서 철하는 순서로 한 장에 두 쪽씩 (양면 인쇄, 짧은 쪽 넘김). 쪽 수는 4의 배수로 빈 쪽을 채운다.
  final bool booklet;

  /// 한 장에 여러 쪽을 모을 때 쪽마다 테두리를 그린다.
  final bool sheetBorder;

  /// 쪽 번호(원래 문서의 쪽 번호)를 찍을 자리.
  final PrintPageNumbers pageNumbers;

  /// 쪽 번호를 "3 / 12"처럼 전체 쪽수와 함께 찍는다.
  final bool pageNumberTotal;

  /// 비스듬히 크게 찍을 글자(비우면 없음).
  final String watermark;

  /// 쪽을 회색 이미지로 바꿔 흑백으로 확실히 찍는다 (글자가 벡터에서 이미지가 되고 오래 걸린다).
  final bool grayscale;

  /// 한 장에 모아 찍는지 (N쪽 모으기 또는 소책자).
  bool get combines => booklet || perSheet > 1;

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
    int? perSheet,
    bool? booklet,
    bool? sheetBorder,
    PrintPageNumbers? pageNumbers,
    bool? pageNumberTotal,
    String? watermark,
    bool? grayscale,
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
    perSheet: perSheet ?? this.perSheet,
    booklet: booklet ?? this.booklet,
    sheetBorder: sheetBorder ?? this.sheetBorder,
    pageNumbers: pageNumbers ?? this.pageNumbers,
    pageNumberTotal: pageNumberTotal ?? this.pageNumberTotal,
    watermark: watermark ?? this.watermark,
    grayscale: grayscale ?? this.grayscale,
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
