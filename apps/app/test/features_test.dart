import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';


Recipe? byId(RecipeStore store, String id) => store.byId(id);

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

  late RecipeStore store;

  Future<void> pumpApp(WidgetTester tester) async {
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();
  }

  group('pan adaptation', () {
    testWidgets('shows bake time for the reference pan by default',
        (tester) async {
      await pumpApp(tester);
      final base = _baseBake(butterCookies);
      final bakeLine = find.byKey(const ValueKey('pan-bake-cookies'));
      expect(bakeLine, findsOneWidget);
      expect(
        tester.widget<Text>(bakeLine).data,
        contains('pan factor ×1.00 · bake ≈ $base min (base $base)'),
      );
    });

    testWidgets('rescales bake time for a bigger pan', (tester) async {
      await pumpApp(tester);
      await tester.enterText(
        find.byKey(const ValueKey('pan-dim-cookies')),
        '24',
      );
      await tester.pumpAndSettle();

      final factor = panScaleFactor(Pan.round(20, 5), Pan.round(24, 5));
      final minutes = scaledBakingTime(
        Duration(minutes: 12),
        factor,
      ).inMinutes;
      expect(
        find.text(
          'pan factor ×${factor.toStringAsFixed(2)} · '
          'bake ≈ $minutes min (base 12)',
        ),
        findsOneWidget,
      );
      expect(minutes, greaterThan(12));
      expect(minutes, lessThan(24));
    });
  });

  group('unit toggle', () {
    testWidgets('switches mass quantities to ounces and back',
        (tester) async {
      await pumpApp(tester);
      expect(find.text('250 g flour'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('toggle-mass-unit')));
      await tester.pumpAndSettle();
      final ounces = 250 / Unit.oz.canonicalFactor;
      expect(
        find.text('${ounces.toStringAsFixed(1)} oz flour'),
        findsNWidgets(2),
      );
      expect(find.text('250 g flour'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('toggle-mass-unit')));
      await tester.pumpAndSettle();
      expect(find.text('250 g flour'), findsNWidgets(2));
    });
  });

  group('substitutions', () {
    testWidgets('long-press offers swaps and the row shows the note',
        (tester) async {
      await pumpApp(tester);
      await tester.longPress(
        find.byKey(const ValueKey('cookies-line-butter')),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('sub-cookies-oil')),
      );
      await tester.pumpAndSettle();

      expect(find.text('211 g oil'), findsOneWidget);
      expect(find.text('melted, same volume roughly'), findsOneWidget);
      expect(find.text('200 g butter'), findsOneWidget);
    });
  });
}

int _baseBake(Recipe recipe) {
  for (final step in recipe.steps) {
    final match = RegExp(r'for (\d+) minutes').firstMatch(step);
    if (match != null) return int.parse(match.group(1)!);
  }
  throw StateError('no bake time in ${recipe.name}');
}
