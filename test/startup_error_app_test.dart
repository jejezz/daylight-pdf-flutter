import 'package:daylight_pdf/platform/startup_error_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows what failed and where the log is', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(StartupErrorApp(error: StateError('boom'), logPath: r'C:\x\startup.log'));
    await tester.pumpAndSettle();
    expect(find.text("Daylight PDF couldn't start"), findsOneWidget);
    expect(find.textContaining(r'C:\x\startup.log'), findsOneWidget);
    expect(find.text('Bad state: boom'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsOneWidget);
  });
}
