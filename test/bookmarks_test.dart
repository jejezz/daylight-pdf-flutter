import 'package:daylight_pdf/viewer/bookmarks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('starts empty', () async {
    expect(await BookmarkStore().load('/a.pdf'), isEmpty);
  });

  test('toggle adds, sorts and removes a page', () async {
    final store = BookmarkStore();
    expect(await store.toggle('/a.pdf', 5), [5]);
    expect(await store.toggle('/a.pdf', 2), [2, 5]);
    expect(await store.toggle('/a.pdf', 5), [2]);
    expect(await store.load('/a.pdf'), [2]);
  });

  test('keeps files apart and normalizes paths', () async {
    final store = BookmarkStore();
    await store.toggle('/x/../a.pdf', 1);
    await store.toggle('/b.pdf', 9);
    expect(await store.load('/a.pdf'), [1]);
    expect(await store.load('/b.pdf'), [9]);
  });

  test('remove drops one page and survives a new store instance', () async {
    await BookmarkStore().toggle('/a.pdf', 3);
    await BookmarkStore().toggle('/a.pdf', 4);
    expect(await BookmarkStore().remove('/a.pdf', 3), [4]);
    expect(await BookmarkStore().load('/a.pdf'), [4]);
  });

  test('a corrupt stored value reads as empty', () async {
    SharedPreferences.setMockInitialValues({'bookmarks': 'not json'});
    expect(await BookmarkStore().load('/a.pdf'), isEmpty);
    expect(await BookmarkStore().toggle('/a.pdf', 1), [1]);
  });
}
