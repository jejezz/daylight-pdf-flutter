import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/pages/page_ranges.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Matcher invalid() =>
      throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.invalidPageRange));

  group('parsePageGroups', () {
    test('single pages, ranges and open-ended ranges', () {
      expect(parsePageGroups('1-3, 5, 8-', 10), [
        [1, 2, 3],
        [5],
        [8, 9, 10],
      ]);
      expect(parsePageGroups('-2', 6), [
        [1, 2],
      ]);
      expect(parsePageGroups(' 4 ', 4), [
        [4],
      ]);
    });

    test('rejects empty, malformed, reversed and out-of-range input', () {
      for (final bad in ['', ',', '1,,2', 'a', '1-b', '--', '3-1', '0', '0-2', '11', '1-11', '2 3', '1-2-3']) {
        expect(() => parsePageGroups(bad, 10), invalid(), reason: bad);
      }
    });

    test('keeps the typed text in the error for the message', () {
      try {
        parsePageGroups(' 9-99 ', 10);
        fail('should throw');
      } on ConversionException catch (e) {
        expect(e.fileName, '9-99');
      }
    });
  });

  test('parsePageList flattens in typed order and keeps duplicates', () {
    expect(parsePageList('3, 1-2, 3', 5), [3, 1, 2, 3]);
  });

  group('splitEveryN', () {
    test('cuts into runs and keeps the remainder', () {
      expect(splitEveryN(5, 2), [
        [1, 2],
        [3, 4],
        [5],
      ]);
      expect(splitEveryN(3, 1), [
        [1],
        [2],
        [3],
      ]);
      expect(splitEveryN(2, 10), [
        [1, 2],
      ]);
      expect(splitEveryN(0, 3), isEmpty);
    });

    test('rejects a non-positive size', () {
      expect(() => splitEveryN(5, 0), invalid());
    });
  });
}
