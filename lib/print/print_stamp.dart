import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import 'print_options.dart';

/// 쪽 번호·워터마크의 글꼴(SeoulNamsan: 한글도 나온다).
Future<Uint8List> loadStampFont() async =>
    (await rootBundle.load('assets/fonts/seoul_namsan_regular.ttf')).buffer.asUint8List();

/// 겹침 PDF의 한 쪽: 눈에 보이는 크기, 찍을 쪽 번호 글자(없으면 null), 가장자리 선을 두를지.
typedef StampPage = ({double width, double height, String? number, bool border});

/// 쪽 번호·워터마크만 담은 PDF를 만든다 (쪽마다 한 장, 크기는 [pages]와 같다). 찍을 것이 없으면 null.
/// 이 PDF의 쪽을 폼 객체로 대상 쪽에 입힌다 (PDFium으로 글자를 직접 넣으면 글꼴 대체 콜백 때문에 메인 스레드에서 위험하다).
Future<Uint8List?> buildStampOverlay({
  required List<StampPage> pages,
  required PrintOptions options,
  required Uint8List fontBytes,
}) async {
  final watermark = options.watermark.trim();
  if (watermark.isEmpty && !pages.any((p) => p.number != null || p.border)) return null;
  final position = options.pageNumbers;
  return Isolate.run(() async {
    final font = pw.Font.ttf(ByteData.sublistView(fontBytes));
    final document = pw.Document(compress: true);
    for (final page in pages) {
      document.addPage(
        pw.Page(
          pageFormat: pdf.PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(
            children: [
              if (watermark.isNotEmpty) _watermark(watermark, font, page.width, page.height),
              if (page.number != null) _number(page.number!, font, position, page.width, page.height),
              if (page.border) _border(page.width, page.height),
            ],
          ),
        ),
      );
    }
    return document.save();
  });
}

/// 글자 폭을 어림해 대각선에 맞는 크기로.
double watermarkFontSize(String text, double width, double height) {
  var units = 0.0;
  for (final r in text.runes) {
    units += r < 128 ? 0.6 : 1.0;
  }
  final diagonal = math.sqrt(width * width + height * height);
  return (0.7 * diagonal / math.max(units, 1)).clamp(16.0, 0.3 * math.min(width, height) * 1.4);
}

pw.Widget _watermark(String text, pw.Font font, double w, double h) => pw.Center(
  // 쪽보다 넓은 글자도 줄바꿈 없이 한 줄로 (회전해서 대각선에 놓인다)
  child: pw.OverflowBox(
    maxWidth: double.infinity,
    maxHeight: double.infinity,
    alignment: pw.Alignment.center,
    child: pw.Transform.rotate(
      angle: math.atan2(h, w) * 0.9,
      child: pw.Opacity(
        opacity: 0.22,
        child: pw.Text(
          text,
          softWrap: false,
          style: pw.TextStyle(font: font, fontSize: watermarkFontSize(text, w, h), color: pdf.PdfColors.grey700),
        ),
      ),
    ),
  ),
);

pw.Widget _number(String text, pw.Font font, PrintPageNumbers where, double w, double h) {
  final style = pw.TextStyle(font: font, fontSize: 9, color: pdf.PdfColors.grey800);
  final label = pw.Text(text, style: style);
  const edge = 12.0, side = 28.0;
  return switch (where) {
    PrintPageNumbers.bottomRight => pw.Positioned(right: side, bottom: edge, child: label),
    PrintPageNumbers.bottomLeft => pw.Positioned(left: side, bottom: edge, child: label),
    PrintPageNumbers.topRight => pw.Positioned(right: side, top: edge, child: label),
    _ => pw.Positioned(
      left: 0,
      right: 0,
      bottom: edge,
      child: pw.Center(child: label),
    ),
  };
}

/// 쪽 가장자리를 두르는 가는 회색 선 (한 장에 모을 때 칸 구분용).
pw.Widget _border(double w, double h) => pw.Positioned(
  left: 0,
  top: 0,
  child: pw.Container(
    width: w,
    height: h,
    decoration: pw.BoxDecoration(border: pw.Border.all(color: pdf.PdfColors.grey600, width: 0.6)),
  ),
);
