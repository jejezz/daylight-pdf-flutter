enum ConversionErrorKind {
  unsupportedFormat,
  cannotRead,
  passwordProtected,
  writeFailed,

  /// Illustrator 파일인데 "PDF 호환 파일 만들기" 없이 저장되어 PDF로 읽을 수 없다.
  notPdfCompatible,

  /// 쪽 범위 문자열이나 쪽 수 값을 해석할 수 없거나 문서 범위를 벗어났다. [ConversionException.fileName]에 입력한 값을 담는다.
  invalidPageRange,
}

/// 변환 실패. 문구는 UI가 [kind]로 ARB에서 고른다 (코드에 사용자용 문장을 두지 않는다).
class ConversionException implements Exception {
  const ConversionException(this.kind, {this.fileName = ''});

  final ConversionErrorKind kind;

  /// 문제가 된 파일 이름 (경로 아님).
  final String fileName;

  @override
  String toString() => 'ConversionException($kind, $fileName)';
}
