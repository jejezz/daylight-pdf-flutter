import 'dart:io';

import 'package:daylight_pdf/convert/conversion_error.dart';
import 'package:daylight_pdf/convert/conversion_queue.dart';
import 'package:daylight_pdf/convert/image_to_pdf.dart';
import 'package:daylight_pdf/convert/output_paths.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('daylight_pdf_convert'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final path = '${dir.path}/$name';
    File(path).writeAsBytesSync(bytes);
    return path;
  }

  group('ImageToPdf', () {
    test('supports common raster extensions, case-insensitively', () {
      expect(ImageToPdf.supports('/a/b.PNG'), isTrue);
      expect(ImageToPdf.supports('/a/b.jpeg'), isTrue);
      expect(ImageToPdf.supports('/a/b.heic'), isFalse);
      expect(ImageToPdf.supports('/a/b.pdf'), isFalse);
    });

    test('makes one PDF page per image, in PNG, JPEG, BMP and GIF', () async {
      final image = img.Image(width: 40, height: 30);
      final inputs = [
        write('a.png', img.encodePng(image)),
        write('b.jpg', img.encodeJpg(image)),
        write('c.bmp', img.encodeBmp(image)),
        write('d.gif', img.encodeGif(image)),
      ];
      final out = '${dir.path}/out.pdf';
      await ImageToPdf.convert(inputs, out);
      final text = String.fromCharCodes(File(out).readAsBytesSync());
      expect(text, startsWith('%PDF'));
      expect(RegExp(r'/Type\s*/Page(?![s\w])').allMatches(text), hasLength(4));
    });

    test('rejects unsupported formats with a typed error', () async {
      final path = write('x.heic', [1, 2, 3]);
      await expectLater(
        ImageToPdf.convert([path], '${dir.path}/o.pdf'),
        throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.unsupportedFormat)),
      );
    });

    test('reports unreadable images instead of writing a broken PDF', () async {
      final path = write('broken.png', [1, 2, 3]);
      final out = '${dir.path}/o.pdf';
      await expectLater(
        ImageToPdf.convert([path], out),
        throwsA(isA<ConversionException>().having((e) => e.kind, 'kind', ConversionErrorKind.cannotRead)),
      );
      expect(File(out).existsSync(), isFalse);
    });
  });

  test('uniquePath never overwrites an existing file', () {
    final first = write('a.pdf', [0]);
    expect(uniquePath(first), '${dir.path}/a (1).pdf');
    write('a (1).pdf', [0]);
    expect(uniquePath(first), '${dir.path}/a (2).pdf');
    expect(uniquePath('${dir.path}/new.pdf'), '${dir.path}/new.pdf');
  });

  group('ConversionQueue', () {
    test('runs jobs in order and keeps going after a failure', () async {
      final queue = ConversionQueue();
      final order = <String>[];
      final ok1 = ConversionJob(
        label: 'one',
        run: () async {
          order.add('one');
          return [];
        },
      );
      final bad = ConversionJob(
        label: 'bad',
        run: () async => throw const ConversionException(ConversionErrorKind.cannotRead, fileName: 'bad'),
      );
      final ok2 = ConversionJob(
        label: 'two',
        run: () async {
          order.add('two');
          return [];
        },
      );
      queue
        ..add(ok1)
        ..add(bad)
        ..add(ok2);
      while (queue.isRunning) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(order, ['one', 'two']);
      expect([ok1.status, bad.status, ok2.status], [JobStatus.done, JobStatus.failed, JobStatus.done]);
      expect(bad.error?.kind, ConversionErrorKind.cannotRead);

      queue.clearFinished();
      expect(queue.jobs, isEmpty);
    });

    test('an unexpected error becomes a failed job, not a crash', () async {
      final queue = ConversionQueue();
      final job = ConversionJob(label: 'x', run: () async => throw StateError('boom'));
      queue.add(job);
      while (queue.isRunning) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(job.status, JobStatus.failed);
    });
  });
}
