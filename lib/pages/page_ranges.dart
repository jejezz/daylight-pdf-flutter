import '../convert/conversion_error.dart';

/// `1-3, 5, 8-` 같은 쪽 범위 문자열을 쪽 번호(1부터) 묶음으로 푼다. 쉼표로 나뉜 한 덩어리가 한 묶음이다.
/// `a-`는 a쪽부터 끝까지, `-b`는 처음부터 b쪽까지. 해석할 수 없거나 [pageCount]를 벗어나면
/// [ConversionErrorKind.invalidPageRange]를 던진다.
List<List<int>> parsePageGroups(String text, int pageCount) {
  ConversionException invalid() => ConversionException(ConversionErrorKind.invalidPageRange, fileName: text.trim());

  final parts = text.split(',').map((s) => s.trim()).toList();
  if (parts.any((s) => s.isEmpty)) throw invalid();
  final groups = <List<int>>[];
  for (final part in parts) {
    final match = RegExp(r'^(\d*)\s*(-?)\s*(\d*)$').firstMatch(part);
    if (match == null) throw invalid();
    final from = match.group(1)!, dash = match.group(2)!, to = match.group(3)!;
    final int start, end;
    if (dash.isEmpty) {
      if (from.isEmpty || to.isNotEmpty) throw invalid();
      start = end = int.parse(from);
    } else {
      if (from.isEmpty && to.isEmpty) throw invalid();
      start = from.isEmpty ? 1 : int.parse(from);
      end = to.isEmpty ? pageCount : int.parse(to);
    }
    if (start < 1 || end > pageCount || start > end) throw invalid();
    groups.add([for (var n = start; n <= end; n++) n]);
  }
  return groups;
}

/// 모든 묶음을 이어 붙인 쪽 번호 (추출용). 순서와 중복은 입력 그대로다.
List<int> parsePageList(String text, int pageCount) => [for (final g in parsePageGroups(text, pageCount)) ...g];

/// [n]쪽마다 끊은 묶음. 마지막 묶음은 남은 쪽만 담는다.
List<List<int>> splitEveryN(int pageCount, int n) {
  if (n < 1) throw ConversionException(ConversionErrorKind.invalidPageRange, fileName: '$n');
  return [
    for (var start = 1; start <= pageCount; start += n) [for (var p = start; p < start + n && p <= pageCount; p++) p],
  ];
}
