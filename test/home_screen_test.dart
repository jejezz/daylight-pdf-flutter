import 'package:daylight_pdf/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isPdfPath accepts only .pdf, case-insensitively', () {
    expect(isPdfPath('/a/b.pdf'), isTrue);
    expect(isPdfPath('/a/B.PDF'), isTrue);
    expect(isPdfPath('/a/b.ai'), isFalse);
    expect(isPdfPath('/a/pdf'), isFalse);
  });
}
