import 'dart:ffi' as ffi;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

/// 열려 있는 PDFium 문서를 바이트로 저장한다 (`FPDF_SaveAsCopy`). 쓰는 콜백은 같은 스레드에서 바로 불리므로
/// `NativeCallable.isolateLocal`로 충분하다.
Uint8List saveDocumentBytes(PDFium pdfium, FPDF_DOCUMENT document) {
  final out = BytesBuilder(copy: false);
  final callable =
      ffi.NativeCallable<
        ffi.Int Function(ffi.Pointer<FPDF_FILEWRITE_>, ffi.Pointer<ffi.Void>, ffi.UnsignedLong)
      >.isolateLocal((ffi.Pointer<FPDF_FILEWRITE_> self, ffi.Pointer<ffi.Void> data, int size) {
        out.add(Uint8List.fromList(data.cast<ffi.Uint8>().asTypedList(size)));
        return 1;
      }, exceptionalReturn: 0);
  final writer = calloc<FPDF_FILEWRITE_>();
  try {
    writer.ref
      ..version = 1
      ..WriteBlock = callable.nativeFunction;
    final Object ok = pdfium.FPDF_SaveAsCopy(document, writer, 0);
    if (ok == false || ok == 0) throw StateError('FPDF_SaveAsCopy failed');
    return out.takeBytes();
  } finally {
    calloc.free(writer);
    callable.close();
  }
}
