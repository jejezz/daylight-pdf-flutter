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
  ConversionErrorKind.converterMissing => l10n.errConverterMissing(e.fileName),
  ConversionErrorKind.conversionTimeout => l10n.errConversionTimeout(e.fileName),
};

/// 변환 뒤 알림 한 줄. 찾지 못한 글꼴은 이름 목록을 툴팁으로 따로 쓴다([conversionWarningDetail]).
String conversionWarningText(AppLocalizations l10n, ConversionWarning w) => switch (w.kind) {
  ConversionWarningKind.fontsSubstituted => l10n.warnFontsSubstituted(w.items.length),
};

/// 경고에 딸린 자세한 내용(툴팁). 없으면 null.
String? conversionWarningDetail(AppLocalizations l10n, ConversionWarning w) => switch (w.kind) {
  ConversionWarningKind.fontsSubstituted =>
    w.items.isEmpty ? null : l10n.warnFontsDetail(_joinLimited(w.items, 8)),
};

String _joinLimited(List<String> items, int max) =>
    items.length <= max ? items.join(', ') : '${items.take(max).join(', ')}, …';
