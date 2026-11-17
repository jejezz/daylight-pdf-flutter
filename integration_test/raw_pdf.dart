import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// 손으로 쓴 PDF: 쪽 [pages]장이 모두 같은 이미지(왼쪽 빨강 | 오른쪽 파랑, 압축되지 않는 잡음 섞임)를 쓴다.
/// 스캔 PDF처럼 큰 객체를 여러 쪽이 공유하는 구조라서, 쪽을 가져올 때 객체를 쪽마다 복사하면 용량이 곧바로 늘어난다.
Uint8List sharedImagePdf({required int pages, String boxes = '/MediaBox [0 0 600 300]'}) {
  const w = 600, h = 300;
  final rnd = Random(7);
  final rgb = Uint8List(w * h * 3);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 3;
      final left = x < w ~/ 2;
      rgb[o] = left ? 215 + rnd.nextInt(40) : rnd.nextInt(40);
      rgb[o + 1] = rnd.nextInt(40);
      rgb[o + 2] = left ? rnd.nextInt(40) : 215 + rnd.nextInt(40);
    }
  }
  final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  void obj(int n, List<int> body) {
    offsets.add(out.length);
    out
      ..add(latin1.encode('$n 0 obj\n'))
      ..add(body)
      ..add(latin1.encode('\nendobj\n'));
  }

  List<int> stream(String dict, List<int> data) => [
    ...latin1.encode('<< $dict /Length ${data.length} >>\nstream\n'),
    ...data,
    ...latin1.encode('\nendstream'),
  ];
  // 1 catalog, 2 pages, 3 image, 4 content, 5.. pages
  obj(1, latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'));
  obj(2, latin1.encode('<< /Type /Pages /Kids [${[for (var i = 0; i < pages; i++) '${5 + i} 0 R'].join(' ')}] /Count $pages >>'));
  obj(3, stream('/Type /XObject /Subtype /Image /Width $w /Height $h /ColorSpace /DeviceRGB /BitsPerComponent 8', rgb));
  obj(4, stream('', latin1.encode('q 600 0 0 300 0 0 cm /Im Do Q')));
  for (var i = 0; i < pages; i++) {
    obj(5 + i, latin1.encode('<< /Type /Page /Parent 2 0 R $boxes /Resources << /XObject << /Im 3 0 R >> >> /Contents 4 0 R >>'));
  }
  final xref = out.length;
  out.add(latin1.encode('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n'));
  for (final o in offsets) {
    out.add(latin1.encode('${o.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(latin1.encode('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n'));
  return out.toBytes();
}

/// 글꼴을 넣지 않은 한글 PDF: 굴림(`/BaseFont`가 CP949 바이트 B1BC B8B2), `UniKS-UCS2-H`로 [text]를 쓴다
/// (한글 워드프로세서·ERP가 만드는 문서 모양). 글꼴 이름이 UTF-8이 아니라서 예전에는 글꼴 요청이 사라지고 글자가 비었다.
Uint8List unembeddedKoreanPdf(String text) {
  final out = BytesBuilder()..add(latin1.encode('%PDF-1.4\n'));
  final offsets = <int>[];
  void obj(int n, List<int> body) {
    offsets.add(out.length);
    out
      ..add(latin1.encode('$n 0 obj\n'))
      ..add(body)
      ..add(latin1.encode('\nendobj\n'));
  }

  final gulim = [0xB1, 0xBC, 0xB8, 0xB2]; // "굴림" (CP949)
  final hex = text.codeUnits.map((c) => c.toRadixString(16).padLeft(4, '0')).join().toUpperCase();
  final content = latin1.encode('BT /F1 40 Tf 20 60 Td <$hex> Tj ET');
  obj(1, latin1.encode('<< /Type /Catalog /Pages 2 0 R >>'));
  obj(2, latin1.encode('<< /Type /Pages /Kids [3 0 R] /Count 1 >>'));
  obj(3, latin1.encode('<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 120] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>'));
  obj(4, [...latin1.encode('<< /Length ${content.length} >>\nstream\n'), ...content, ...latin1.encode('\nendstream')]);
  obj(5, [...latin1.encode('<< /Type /Font /Subtype /Type0 /BaseFont /'), ...gulim, ...latin1.encode(' /DescendantFonts [6 0 R] /Encoding /UniKS-UCS2-H >>')]);
  obj(6, [
    ...latin1.encode('<< /Type /Font /Subtype /CIDFontType2 /BaseFont /'),
    ...gulim,
    ...latin1.encode(' /WinCharSet 128 /FontDescriptor 7 0 R /CIDSystemInfo << /Registry (Adobe) /Ordering (Korea1) /Supplement 1 >> /DW 1000 >>'),
  ]);
  obj(7, [
    ...latin1.encode('<< /Type /FontDescriptor /Ascent 880 /CapHeight 800 /Descent -120 /FontBBox [0 -148 1001 880] /ItalicAngle 0 /StemV 93 /Flags 6 /FontName /'),
    ...gulim,
    ...latin1.encode(' >>'),
  ]);
  final xref = out.length;
  out.add(latin1.encode('xref\n0 ${offsets.length + 1}\n0000000000 65535 f \n'));
  for (final o in offsets) {
    out.add(latin1.encode('${o.toString().padLeft(10, '0')} 00000 n \n'));
  }
  out.add(latin1.encode('trailer\n<< /Size ${offsets.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n'));
  return out.toBytes();
}
