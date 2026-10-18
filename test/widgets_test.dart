import 'package:daylight_pdf/theme/app_theme.dart';
import 'package:daylight_pdf/widgets/drop_zone.dart';
import 'package:daylight_pdf/widgets/glass_card.dart';
import 'package:daylight_pdf/widgets/status_pill.dart';
import 'package:daylight_pdf/widgets/tool_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {Brightness brightness = Brightness.light}) => MaterialApp(
  theme: brightness == Brightness.light ? AppTheme.light() : AppTheme.dark(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('GlassCard shows its child and reacts to taps only when it has onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(GlassCard(onTap: () => taps++, child: const Text('card'))));
    await tester.tap(find.text('card'));
    expect(taps, 1);

    await tester.pumpWidget(_app(const GlassCard(child: Text('static'))));
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('a selected GlassCard has a thicker primary border', (tester) async {
    await tester.pumpWidget(_app(const GlassCard(selected: true, child: Text('x'))));
    final material = tester.widget<Material>(
      find.descendant(of: find.byType(GlassCard), matching: find.byType(Material)),
    );
    final side = (material.shape! as RoundedRectangleBorder).side;
    expect(side.width, 2);
    expect(side.color, AppColors.primaryDeep);
  });

  testWidgets('StatusPill uses the readable text variant on light and the bright one on dark', (tester) async {
    Color textColor(WidgetTester t) => t.widget<Text>(find.text('완료')).style!.color!;

    await tester.pumpWidget(_app(const StatusPill(label: '완료', tone: PillTone.success)));
    expect(textColor(tester), AppColors.successTextLight);

    await tester.pumpWidget(
      _app(
        const StatusPill(label: '완료', tone: PillTone.success),
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpAndSettle(); // 테마 전환 애니메이션이 끝나길 기다린다
    expect(textColor(tester), AppColors.success);
  });

  testWidgets('ToolChip: label hidden when compact (tooltip stays), disabled when no handler', (tester) async {
    await tester.pumpWidget(_app(const ToolChip(icon: Icons.delete, label: '삭제', onPressed: null, compact: true)));
    expect(find.text('삭제'), findsNothing);
    expect(find.byTooltip('삭제'), findsOneWidget);

    var pressed = 0;
    await tester.pumpWidget(_app(ToolChip(icon: Icons.delete, label: '삭제', onPressed: () => pressed++)));
    await tester.tap(find.text('삭제'));
    expect(pressed, 1);
  });

  testWidgets('DropZone renders its content inside a dashed frame', (tester) async {
    await tester.pumpWidget(_app(DropZone(onDrop: (_) {}, child: const Text('여기에 놓기'))));
    expect(find.text('여기에 놓기'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
