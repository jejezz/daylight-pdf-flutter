import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import 'conversion_error.dart';

/// SVG → PDF. 벡터 그대로 넣으므로 확대해도 선명하다. 쪽 크기는 SVG의 width/height(없으면 viewBox)이고,
/// px는 CSS 규칙대로 0.75pt로 바꾼다. `pdf` 패키지가 그리지 못하는 SVG 기능은 빠질 수 있다.
/// SVG 글자에 기본 글꼴(Latin-1)로 못 담는 문자(한글 등)가 있을 때 대신 쓸 TTF 글꼴.
typedef SvgFallbackFonts = ({Uint8List regular, Uint8List bold});

abstract final class SvgToPdf {
  static bool supports(String path) => p.extension(path).toLowerCase() == '.svg';

  /// [loadFallbackFonts]는 SVG 글자에 한글처럼 기본 글꼴로 못 담는 문자가 있을 때만 (메인 isolate에서) 불린다.
  /// 없으면 그런 SVG는 [ConversionErrorKind.cannotRead]로 실패한다.
  static Future<void> convert(
    String input,
    String outputPath, {
    Future<SvgFallbackFonts> Function()? loadFallbackFonts,
  }) async {
    final name = p.basename(input);
    final String svg;
    try {
      svg = File(input).readAsStringSync();
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    }
    final size = pageSize(svg);
    if (size == null) throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    final fonts = loadFallbackFonts != null && needsUnicodeFont(svg) ? await loadFallbackFonts() : null;
    await Isolate.run(() => _write(name, svg, size, fonts, outputPath));
  }

  /// `<text>` 안에 Latin-1(PDF 기본 글꼴)로 못 담는 문자가 있는지.
  static bool needsUnicodeFont(String svg) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(svg);
    } on XmlException {
      return false;
    }
    return document
        .findAllElements('text')
        .expand((e) => e.descendants.whereType<XmlText>())
        .any((t) => t.value.runes.any((r) => r > 0xFF));
  }

  /// 쪽 크기(pt). 읽을 수 없는 SVG면 null.
  static ({double width, double height})? pageSize(String svg) {
    final XmlElement root;
    try {
      root = XmlDocument.parse(svg).rootElement;
    } on XmlException {
      return null;
    }
    if (root.name.local != 'svg') return null;
    final width = _length(root.getAttribute('width'));
    final height = _length(root.getAttribute('height'));
    if (width != null && height != null) return (width: width, height: height);
    final box = root.getAttribute('viewBox')?.trim().split(RegExp(r'[\s,]+')).map(double.tryParse).toList();
    if (box != null && box.length == 4 && box[2] != null && box[3] != null && box[2]! > 0 && box[3]! > 0) {
      return (width: width ?? box[2]! * _pxToPt, height: height ?? box[3]! * _pxToPt);
    }
    return null;
  }

  static const _pxToPt = 0.75;

  static double? _length(String? value) {
    if (value == null) return null;
    final match = RegExp(r'^\s*([0-9]*\.?[0-9]+)\s*(px|pt|pc|mm|cm|in)?\s*$').firstMatch(value);
    if (match == null) return null; // 퍼센트 등 절대 크기가 아닌 값
    final number = double.parse(match.group(1)!);
    final points = switch (match.group(2)) {
      'pt' => number,
      'pc' => number * 12,
      'mm' => number * 72 / 25.4,
      'cm' => number * 72 / 2.54,
      'in' => number * 72,
      _ => number * _pxToPt,
    };
    return points > 0 ? points : null;
  }

  static Future<void> _write(
    String name,
    String svg,
    ({double width, double height}) size,
    SvgFallbackFonts? fonts,
    String outputPath,
  ) async {
    final regular = fonts == null ? null : pw.Font.ttf(ByteData.sublistView(fonts.regular));
    final bold = fonts == null ? null : pw.Font.ttf(ByteData.sublistView(fonts.bold));
    final document = pw.Document();
    try {
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(size.width, size.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.SvgImage(
            svg: svg,
            fit: pw.BoxFit.contain,
            width: size.width,
            height: size.height,
            customFontLookup: fonts == null ? null : (family, style, weight) => _isBold(weight) ? bold : regular,
          ),
        ),
      );
      File(outputPath).writeAsBytesSync(await document.save(), flush: true);
    } on FileSystemException {
      throw ConversionException(ConversionErrorKind.writeFailed, fileName: p.basename(outputPath));
    } on ConversionException {
      rethrow;
    } catch (_) {
      throw ConversionException(ConversionErrorKind.cannotRead, fileName: name);
    }
  }

  static bool _isBold(String weight) => weight == 'bold' || (int.tryParse(weight) ?? 400) >= 600;
}
