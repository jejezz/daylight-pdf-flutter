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
