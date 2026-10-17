enum ConversionErrorKind { unsupportedFormat, cannotRead, passwordProtected, writeFailed }

/// 변환 실패. 문구는 UI가 [kind]로 ARB에서 고른다 (코드에 사용자용 문장을 두지 않는다).
class ConversionException implements Exception {
  const ConversionException(this.kind, {this.fileName = ''});

  final ConversionErrorKind kind;

  /// 문제가 된 파일 이름 (경로 아님).
  final String fileName;

  @override
  String toString() => 'ConversionException($kind, $fileName)';
}
