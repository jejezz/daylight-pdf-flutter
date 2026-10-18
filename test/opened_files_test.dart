import 'dart:io';

import 'package:daylight_pdf/home/opened_files.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory base;
  late OpenedFiles opened;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('daylight_opened');
    base = Directory(p.join(temp.path, 'opened'));
    opened = OpenedFiles(baseDirectory: () async => base);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  File source(String name, [String text = 'pdf']) => File(p.join(temp.path, 'cache', name))
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  test('adopt copies the file into the app folder and keeps its name', () async {
    final src = source('report.pdf', 'hello');
    final copy = await opened.adopt(src.path);
    expect(p.basename(copy), 'report.pdf');
    expect(p.isWithin(base.path, copy), isTrue);
    expect(File(copy).readAsStringSync(), 'hello');
    // 원본(캐시)이 사라져도 복사본은 남는다
    src.deleteSync();
    expect(File(copy).existsSync(), isTrue);
  });

  test('the same name opened twice does not collide', () async {
    final a = await opened.adopt(source('same.pdf', 'one').path);
    final b = await opened.adopt(source('same.pdf', 'two').path);
    expect(a, isNot(b));
    expect(File(a).readAsStringSync(), 'one');
    expect(File(b).readAsStringSync(), 'two');
  });

  test('the same file opened again reuses its copy (no duplicate in the recent list)', () async {
    final first = await opened.adopt(source('again.pdf', 'same content').path);
    final second = await opened.adopt(source('again.pdf', 'same content').path);
    expect(second, first);
    expect(base.listSync().length, 1);
    // 이름이 같아도 내용이 다르면 다른 파일이다 (같은 길이여도)
    final third = await opened.adopt(source('again.pdf', 'other  content').path);
    expect(third, isNot(first));
    expect(base.listSync().length, 2);
  });

  test('a big file is compared in chunks and a difference near the end is found', () async {
    final a = File(p.join(temp.path, 'cache', 'big.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(List<int>.generate(300000, (i) => i % 251));
    final first = await opened.adopt(a.path);
    final changed = List<int>.generate(300000, (i) => i % 251)..[299999] = 7;
    final b = File(p.join(temp.path, 'cache2', 'big.pdf'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(changed);
    expect(await opened.adopt(b.path), isNot(first), reason: 'one different byte at the very end');
    expect(await opened.adopt(a.path), first, reason: 'the identical file still maps to the first copy');
  });

  test('a file already in the app folder is returned as is', () async {
    final copy = await opened.adopt(source('x.pdf').path);
    expect(await opened.adopt(copy), copy);
    expect(base.listSync().length, 1);
  });

  test('a missing source falls back to the original path instead of failing', () async {
    final missing = p.join(temp.path, 'nope.pdf');
    expect(await opened.adopt(missing), missing);
  });

  test('prune removes copies that are no longer in the recent list', () async {
    final keep = await opened.adopt(source('keep.pdf').path);
    final drop = await opened.adopt(source('drop.pdf').path);
    await opened.prune([keep]);
    expect(File(keep).existsSync(), isTrue);
    expect(File(drop).existsSync(), isFalse);
    expect(Directory(p.dirname(drop)).existsSync(), isFalse, reason: 'the empty folder goes too');
  });

  test('prune does nothing when the app folder does not exist yet', () async {
    await opened.prune(const []);
    expect(base.existsSync(), isFalse);
  });
}
