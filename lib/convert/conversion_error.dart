enum ConversionErrorKind {
  unsupportedFormat,
  cannotRead,
  passwordProtected,
  writeFailed,

  /// Illustrator 파일인데 "PDF 호환 파일 만들기" 없이 저장되어 PDF로 읽을 수 없다.
  notPdfCompatible,

  /// 쪽 범위 문자열이나 쪽 수 값을 해석할 수 없거나 문서 범위를 벗어났다. [ConversionException.fileName]에 입력한 값을 담는다.
  invalidPageRange,

  /// 변환에 쓰는 외부 프로그램(HWP 변환기 rhwp)을 실행할 수 없다. 설치가 잘못됐거나 파일이 지워졌다.
  converterMissing,

  /// 변환기가 제한 시간 안에 끝나지 않아 멈췄다.
  conversionTimeout,
}

enum ConversionWarningKind {
  /// 문서가 쓰는 글꼴 중 이 컴퓨터에 없는 것이 있어 다른 글꼴로 바꿔 그렸다. 줄바꿈·글자 모양이 원본과 다를 수 있다.
  fontsSubstituted,
}

/// 변환은 끝났지만 사용자가 알아야 하는 점. 문구는 UI가 [kind]로 ARB에서 고른다.
class ConversionWarning {
  const ConversionWarning(this.kind, {this.items = const []});

  final ConversionWarningKind kind;

  /// 경고가 가리키는 대상(예: 찾지 못한 글꼴 이름). 외부 도구가 준 값이라 길이·개수를 이미 줄였다.
  final List<String> items;

  @override
  String toString() => 'ConversionWarning($kind, $items)';
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
