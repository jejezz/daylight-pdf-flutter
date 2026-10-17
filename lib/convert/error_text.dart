import '../l10n/app_localizations.dart';
import 'conversion_error.dart';

/// 변환·페이지 도구가 던진 [ConversionException]을 사용자 문구로 바꾼다.
String conversionErrorText(AppLocalizations l10n, ConversionException e) => switch (e.kind) {
  ConversionErrorKind.unsupportedFormat => l10n.errUnsupportedFormat(e.fileName),
  ConversionErrorKind.cannotRead => l10n.errCannotRead(e.fileName),
  ConversionErrorKind.passwordProtected => l10n.errPasswordProtected(e.fileName),
  ConversionErrorKind.writeFailed => l10n.errWriteFailed(e.fileName),
  ConversionErrorKind.notPdfCompatible => l10n.errNotPdfCompatible(e.fileName),
  ConversionErrorKind.invalidPageRange => l10n.errInvalidRange(e.fileName),
};
