import 'package:bellenissimos_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(const app.BellenissimosApp());
    await tester.pumpAndSettle();
  }

  testWidgets('renders both recipes with base amounts', (tester) async {
    await pumpApp(tester);
    expect(find.text('Butter cookies'), findsOneWidget);
    expect(find.text('Makes 24 cookies'), findsOneWidget);
    expect(find.text('250 g flour'), findsOneWidget);
    expect(find.text('200 g butter'), findsOneWidget);
    expect(find.text('100 g sugar'), findsOneWidget);
    expect(find.text('1 piece egg'), findsOneWidget);
    expect(find.text('Sandwich loaf'), findsOneWidget);
    expect(find.text('Makes 900 g'), findsOneWidget);
    expect(find.text('500 g flour'), findsOneWidget);
    expect(find.text('320 g water'), findsOneWidget);
    expect(find.text('10 g salt'), findsOneWidget);
  });

  testWidgets('cookies slider rescales lines and yield', (tester) async {
    await pumpApp(tester);
    tester
        .widget<Slider>(find.byKey(const ValueKey('cookies-slider')))
        .onChanged!(36);
    await tester.pumpAndSettle();
    expect(find.text('Target: 36 cookies'), findsOneWidget);
    expect(find.text('Makes 36 cookies'), findsOneWidget);
    expect(find.text('375 g flour'), findsOneWidget);
    expect(find.text('300 g butter'), findsOneWidget);
    expect(find.text('150 g sugar'), findsOneWidget);
    expect(find.text('1.5 piece egg'), findsOneWidget);
  });

  testWidgets('loaf slider rescales lines and yield', (tester) async {
    await pumpApp(tester);
    tester
        .widget<Slider>(find.byKey(const ValueKey('loaf-slider')))
        .onChanged!(1800);
    await tester.pumpAndSettle();
    expect(find.text('Target: 1800 g'), findsOneWidget);
    expect(find.text('Makes 1800 g'), findsOneWidget);
    expect(find.text('1000 g flour'), findsOneWidget);
    expect(find.text('640 g water'), findsOneWidget);
    expect(find.text('20 g salt'), findsOneWidget);
  });

  testWidgets('dragging the cookies slider updates the amounts',
      (tester) async {
    await pumpApp(tester);
    const flourLine = ValueKey('cookies-line-flour');
    final before =
        (tester.widget<ListTile>(find.byKey(flourLine)).title as Text).data;
    await tester.drag(
        find.byKey(const ValueKey('cookies-slider')), const Offset(120, 0));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<ListTile>(find.byKey(flourLine)).title as Text).data,
      isNot(before),
    );
    expect(find.text('250 g flour'), findsNothing);
  });

  testWidgets('main() boots the app', (tester) async {
    app.main();
    await tester.pumpAndSettle();
    expect(find.text('Recipes'), findsOneWidget);
  });
}
