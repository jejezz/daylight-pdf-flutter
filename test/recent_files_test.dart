import 'dart:io';

import 'package:daylight_pdf/home/recent_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory dir;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('daylight_pdf_recent');
  });
  tearDown(() => dir.deleteSync(recursive: true));

  String file(String name) {
    final f = File('${dir.path}/$name')..writeAsStringSync('x');
    return f.path;
  }

  test('starts empty', () async {
    expect(await RecentFiles().load(), isEmpty);
  });

  test('puts the newest first and keeps each file once', () async {
    final recents = RecentFiles();
    final a = file('a.pdf'), b = file('b.pdf'), c = file('c.pdf');
    await recents.add(a);
    await recents.add(b);
    await recents.add(c);
    expect(await recents.load(), [c, b, a]);

    await recents.add(a); // 다시 열면 맨 앞으로 옮겨질 뿐 중복되지 않는다
    expect(await recents.load(), [a, c, b]);
  });

  test('keeps at most the limit and drops the oldest', () async {
    final recents = RecentFiles(limit: 3);
    final files = [for (var i = 0; i < 5; i++) file('f$i.pdf')];
    for (final f in files) {
      await recents.add(f);
    }
    expect(await recents.load(), [files[4], files[3], files[2]]);
  });

  test('the default limit is 10', () async {
    final recents = RecentFiles();
    for (var i = 0; i < 12; i++) {
      await recents.add(file('f$i.pdf'));
    }
    expect((await recents.load()).length, 10);
  });

  test('the same file spelled differently counts as one', () async {
    final recents = RecentFiles();
    final a = file('a.pdf');
    await recents.add(a);
    await recents.add('${dir.path}/./a.pdf');
    expect(await recents.load(), [a]);
  });

  test('remove and clear', () async {
    final recents = RecentFiles();
    final a = file('a.pdf'), b = file('b.pdf');
    await recents.add(a);
    await recents.add(b);
    await recents.remove(a);
    expect(await recents.load(), [b]);
    await recents.remove('${dir.path}/never-added.pdf'); // 없는 것을 지워도 문제없다
    expect(await recents.load(), [b]);
    await recents.clear();
    expect(await recents.load(), isEmpty);
  });

  test('loadExisting hides files that are gone and forgets them', () async {
    final recents = RecentFiles();
    final a = file('a.pdf'), b = file('b.pdf');
    await recents.add(a);
    await recents.add(b);
    File(a).deleteSync();

    expect(await recents.loadExisting(), [b]);
    expect(await recents.load(), [b], reason: 'the missing entry is removed from storage too');
  });

  test('the list survives a restart (it lives in SharedPreferences)', () async {
    final a = file('a.pdf');
    await RecentFiles().add(a);
    expect(await RecentFiles().load(), [a]);
  });

  group('shortFolder', () {
    test('a shallow folder is shown as is', () {
      expect(shortFolder('/Users/me/docs/a.pdf', home: '/nowhere'), '/Users/me/docs');
      expect(shortFolder('/a.pdf', home: '/nowhere'), '/');
    });

    test('the home folder becomes ~', () {
      expect(shortFolder('/Users/me/a.pdf', home: '/Users/me'), '~');
      expect(shortFolder('/Users/me/Documents/a.pdf', home: '/Users/me'), '~/Documents');
      expect(shortFolder('/Users/me/Documents/Work/a.pdf', home: '/Users/me'), '~/Documents/Work');
    });

    test('a deep folder keeps only its last two levels', () {
      expect(shortFolder('/Users/me/Documents/Work/2026/Reports/a.pdf', home: '/Users/me'), '…/2026/Reports');
      expect(shortFolder('/var/folders/hb/abc123/T/daylight/a.pdf', home: '/Users/me'), '…/T/daylight');
    });

    test('a sibling folder that merely starts with the home name is not shortened', () {
      expect(shortFolder('/Users/meow/a.pdf', home: '/Users/me'), '/Users/meow');
    });
  });
}
