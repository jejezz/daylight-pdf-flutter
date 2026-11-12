import 'package:daylight_pdf/platform/incoming_files.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('art.zoomon.daylightpdf/incoming');

  Future<void> send(String method, Object? arguments) => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .handlePlatformMessage(channel.name, const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)), (_) {});

  testWidgets('macOS: 시작할 때 받은 파일 목록과 그 뒤에 연 파일을 받는다', (tester) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'initialFiles' ? ['/a.pdf', '/b.png'] : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final incoming = IncomingFiles();
    addTearDown(incoming.dispose);
    final received = <List<String>>[];
    incoming.opened.listen(received.add);

    expect(await incoming.start(), ['/a.pdf', '/b.png']);
    expect(calls, ['initialFiles']);

    await send('filesOpened', ['/c.svg', '/d.ai']);
    await tester.pump();
    expect(received, [
      ['/c.svg', '/d.ai'],
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Android: 파일 하나씩 받는다', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'initialFile' ? '/cache/x.pdf' : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final incoming = IncomingFiles();
    addTearDown(incoming.dispose);
    final received = <List<String>>[];
    incoming.opened.listen(received.add);

    expect(await incoming.start(), ['/cache/x.pdf']);
    await send('fileOpened', '/cache/y.pdf');
    await tester.pump();
    expect(received, [
      ['/cache/y.pdf'],
    ]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('Windows·Linux: 채널을 쓰지 않는다(명령줄 인자로 온다)', (tester) async {
    var called = false;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      called = true;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));

    final incoming = IncomingFiles();
    addTearDown(incoming.dispose);
    expect(await incoming.start(), isEmpty);
    expect(called, isFalse);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
