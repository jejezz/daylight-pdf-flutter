import 'package:daylight_pdf/pages/reorder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const abcd = ['a', 'b', 'c', 'd'];

  test('moves an item forward or backward, "before" being the target position in the old list', () {
    expect(moveBefore(abcd, 0, 3), ['b', 'c', 'a', 'd']); // a를 d 앞으로
    expect(moveBefore(abcd, 3, 1), ['a', 'd', 'b', 'c']); // d를 b 앞으로
    expect(moveBefore(abcd, 0, 4), ['b', 'c', 'd', 'a']); // 맨 뒤로
    expect(moveBefore(abcd, 2, 0), ['c', 'a', 'b', 'd']); // 맨 앞으로
  });

  test('dropping on itself or right after itself keeps the order', () {
    expect(moveBefore(abcd, 1, 1), abcd);
    expect(moveBefore(abcd, 1, 2), abcd);
    expect(moveBefore(abcd, 3, 4), abcd);
  });

  test('does not change the input list and keeps every item', () {
    final input = List.of(abcd);
    final out = moveBefore(input, 1, 4);
    expect(input, abcd);
    expect(out.toSet(), abcd.toSet());
    expect(out.length, 4);
  });
}
