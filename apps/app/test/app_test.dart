import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/recipe_card.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';


void main() {
  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
      return const StandardMessageCodec().encodeMessage(
        '/tmp/opencode/bellenissimos-test',
      );
    });
  });

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const app.BellenissimosApp());
    await tester.pumpAndSettle();
  }

  testWidgets('renders every recipe as a normal card', (tester) async {
    await pumpApp(tester);
    expect(find.text('Butter cookies'), findsOneWidget);
    expect(find.text('Makes 24 cookies'), findsNWidgets(2));
    expect(find.text('250 g flour'), findsNWidgets(2));
    expect(find.text('200 g butter'), findsNWidgets(2));
    expect(find.text('100 g sugar'), findsNWidgets(2));
    expect(find.text('1 piece egg'), findsOneWidget);
    expect(find.text('120 g applesauce'), findsOneWidget);
    expect(find.text('VARIANT'), findsNothing);
    expect(find.text('Sandwich loaf'), findsOneWidget);
    expect(find.text('Makes 900 g'), findsOneWidget);
    expect(find.text('500 g flour'), findsOneWidget);
    expect(find.text('320 g water'), findsOneWidget);
    expect(find.text('10 g salt'), findsOneWidget);
  });

  testWidgets('an egg-free variant scales like a normal recipe', (
    tester,
  ) async {
    await pumpApp(tester);
    tester
        .widget<Slider>(find.byKey(const ValueKey('eggfree-slider')))
        .onChanged!(36);
    await tester.pumpAndSettle();
    expect(find.text('Target: 36 cookies'), findsOneWidget);
    expect(find.text('Makes 36 cookies'), findsOneWidget);
    expect(find.text('375 g flour'), findsOneWidget);
    expect(find.text('variant of Butter cookies'), findsOneWidget);
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
    tester.widget<Slider>(find.byKey(const ValueKey('loaf-slider'))).onChanged!(
      1800,
    );
    await tester.pumpAndSettle();
    expect(find.text('Target: 1800 g'), findsOneWidget);
    expect(find.text('Makes 1800 g'), findsOneWidget);
    expect(find.text('1000 g flour'), findsOneWidget);
    expect(find.text('640 g water'), findsOneWidget);
    expect(find.text('20 g salt'), findsOneWidget);
  });

  testWidgets('dragging the cookies slider updates the amounts', (
    tester,
  ) async {
    await pumpApp(tester);
    const flourLine = ValueKey('cookies-line-flour');
    final before =
        (tester.widget<ListTile>(find.byKey(flourLine)).title as Text).data;
    await tester.drag(
      find.byKey(const ValueKey('cookies-slider')),
      const Offset(120, 0),
    );
    await tester.pumpAndSettle();
    expect(
      (tester.widget<ListTile>(find.byKey(flourLine)).title as Text).data,
      isNot(before),
    );
    expect(find.text('250 g flour'), findsOneWidget);
  });

  testWidgets('shows numbered steps, family lines and timestamps', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(
      find.text('1. mix the flour, water and salt into a shaggy dough'),
      findsOneWidget,
    );
    expect(
      find.text(
        '4. shape, proof 45 minutes, then bake at 220 C for 35 minutes',
      ),
      findsOneWidget,
    );
    expect(find.text('2. beat in the egg'), findsOneWidget);
    expect(find.text('2. beat in the applesauce'), findsOneWidget);
    expect(find.text('variant of Butter cookies'), findsOneWidget);
    expect(find.text('variants: Egg-free butter cookies'), findsOneWidget);
    expect(
      find.text('created 2026-01-15 · updated 2026-01-20'),
      findsOneWidget,
    );
    expect(
      find.text('created 2026-01-16 · updated 2026-01-16'),
      findsOneWidget,
    );
    expect(
      find.text('created 2026-02-01 · updated 2026-02-03'),
      findsOneWidget,
    );
  });

  test('timestampLine is null when a recipe is undated', () {
    const undated = Recipe(
      name: 'ad hoc',
      yield: YieldSpec(count: 1),
      lines: [],
    );
    expect(timestampLine(undated), isNull);
    expect(
      timestampLine(butterCookies),
      'created 2026-01-15 · updated 2026-01-20',
    );
  });

  testWidgets('main() boots the app', (tester) async {
    await app.main();
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Recipes'), findsOneWidget);
  });

  testWidgets('cards build lazily on a real screen', (tester) async {
    await tester.pumpWidget(const app.BellenissimosApp());
    await tester.pumpAndSettle();
    expect(find.text('Butter cookies'), findsOneWidget);
    expect(find.text('Sandwich loaf'), findsNothing);
  });

  group('recipe filter', () {
    testWidgets('narrows the box to matching names', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipe-filter')),
        'loaf',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sandwich loaf'), findsOneWidget);
      expect(find.text('Butter cookies'), findsNothing);
      expect(find.text('Egg-free butter cookies'), findsNothing);
    });

    testWidgets('matches names case-insensitively', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipe-filter')),
        'LOAF',
      );
      await tester.pumpAndSettle();

      expect(find.text('Sandwich loaf'), findsOneWidget);
      expect(find.text('Butter cookies'), findsNothing);
    });

    testWidgets('an empty filter restores every card', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipe-filter')),
        'loaf',
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('recipe-filter')), '');
      await tester.pumpAndSettle();

      expect(find.text('Butter cookies'), findsOneWidget);
      expect(find.text('Egg-free butter cookies'), findsOneWidget);
      expect(find.text('Sandwich loaf'), findsOneWidget);
    });

    testWidgets('an unmatched filter shows a note', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('recipe-filter')),
        'zebra',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('No recipes match'), findsOneWidget);
      expect(find.text('Butter cookies'), findsNothing);
    });

    testWidgets('a keystroke does not rebuild the page chrome', (tester) async {
      await pumpApp(tester);
      final toggleBefore =
          tester.widget(find.byKey(const ValueKey('toggle-mass-unit')));
      final filterBefore =
          tester.widget(find.byKey(const ValueKey('recipe-filter')));
      await tester.enterText(
        find.byKey(const ValueKey('recipe-filter')),
        'loaf',
      );
      await tester.pumpAndSettle();

      expect(
        tester.widget(find.byKey(const ValueKey('toggle-mass-unit'))),
        same(toggleBefore),
      );
      expect(
        tester.widget(find.byKey(const ValueKey('recipe-filter'))),
        same(filterBefore),
      );
    });
  });
}
