/// [items]에서 [from]번 항목을 꺼내 [before]번 항목 앞에 끼운 새 목록을 돌려준다.
/// [before]는 0..items.length (items.length면 맨 뒤). 제자리로 놓는 경우(from 또는 from+1)는 같은 순서다.
List<T> moveBefore<T>(List<T> items, int from, int before) {
  assert(from >= 0 && from < items.length, 'from out of range');
  assert(before >= 0 && before <= items.length, 'before out of range');
  final result = List<T>.of(items);
  final item = result.removeAt(from);
  result.insert(before > from ? before - 1 : before, item);
  return result;
}
