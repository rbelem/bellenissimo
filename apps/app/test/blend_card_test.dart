import 'package:bellenissimos_app/blend_card.dart';
import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/blend_store.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_app/theme.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BlendRecord _sweetener({
  required String id,
  required String name,
  required Map<String, double> grams,
  required Map<String, double> sweetness,
}) => BlendRecord(
  blend: SweetenerBlend(
    id: id,
    name: name,
    grams: {
      for (final entry in grams.entries)
        Ingredient(
          entry.key,
          gramsPerMl: seedIngredients[entry.key]?.gramsPerMl,
        ): entry.value,
    },
    sweetnessPerGram: {
      for (final entry in sweetness.entries) Ingredient(entry.key): entry.value,
    },
  ),
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 2),
);

BlendRecord _flourMix() => BlendRecord(
  blend: FlourMix(
    id: 'bread-mix',
    name: 'Bread mix',
    grams: {
      seedIngredients['flour']!: 700,
      seedIngredients['whole_wheat_flour']!: 300,
    },
    proteinPct: {
      seedIngredients['flour']!: 10,
      seedIngredients['whole_wheat_flour']!: 14,
    },
  ),
);

/// 100 g erythritol + 100 g xylitol at 0.7 / 1.0 per gram.
BlendRecord _eryXyl() => _sweetener(
  id: 'ery-xyl',
  name: 'Erythritol xylitol',
  grams: {'erythritol': 100, 'xylitol': 100},
  sweetness: {'erythritol': 0.7, 'xylitol': 1.0},
);

/// 140 g erythritol + 60 g sugar lands at ×0.79 — losesBulk.
BlendRecord _weak() => _sweetener(
  id: 'weak-swap',
  name: 'Half sugar swap',
  grams: {'erythritol': 140, 'sugar': 60},
  sweetness: {'erythritol': 0.7, 'sugar': 1.0},
);

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
  late BlendStore blends;

  Future<void> pumpApp(WidgetTester tester, {bool seedBlends = true}) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    blends = BlendStore.inMemory(store);
    if (seedBlends) {
      blends.upsertAll([_eryXyl(), _weak(), _flourMix()]);
    }
    await tester.pumpWidget(
      app.BellenissimosApp(store: store, blendStore: blends),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('blend cards sit after the recipes under one divider', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('blends'), findsOneWidget);
    expect(find.text('Sandwich loaf'), findsOneWidget);
    expect(find.text('Erythritol xylitol'), findsOneWidget);
    expect(find.text('Half sugar swap'), findsOneWidget);
    expect(find.text('Bread mix'), findsOneWidget);
    expect(find.text('sweetener blend'), findsNWidgets(2));
    expect(find.text('flour mix'), findsOneWidget);
    expect(
      find.text('created 2026-03-01 · updated 2026-03-02'),
      findsNWidgets(2),
    );
  });

  testWidgets('composition rows and the total render in grams', (tester) async {
    await pumpApp(tester);

    expect(find.text('100 g erythritol'), findsOneWidget);
    expect(find.text('140 g erythritol'), findsOneWidget);
    expect(find.text('100 g xylitol'), findsOneWidget);
    expect(find.text('60 g sugar'), findsOneWidget);
    expect(find.text('Total 200 g'), findsNWidgets(2));
    expect(find.text('700 g flour'), findsOneWidget);
    expect(find.text('Total 1000 g'), findsOneWidget);
  });

  testWidgets('derived readouts follow the blend kind', (tester) async {
    await pumpApp(tester);

    expect(find.text('sweetness ×0.85 of sugar'), findsOneWidget);
    expect(find.text('sweetness ×0.79 of sugar'), findsOneWidget);
    expect(find.text('protein 11.2 %'), findsOneWidget);
    expect(find.text('bread hydration ≈ 62 %'), findsOneWidget);
  });

  testWidgets('a weak sweetener blend carries the pencil bulk note', (
    tester,
  ) async {
    await pumpApp(tester);

    final note = find.text("won't bulk like sugar — structure will shift");
    expect(note, findsOneWidget);
    final tokens = Theme.of(tester.element(note)).extension<BoxTokens>()!;
    expect(tester.widget<Text>(note).style!.color, tokens.annotation);
  });

  testWidgets('the replace-sugar field computes live and rolls', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(
      find.byKey(const ValueKey('blend-ery-xyl-sugar-result')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('blend-ery-xyl-sugar-input')),
      '100',
    );
    await tester.pumpAndSettle();
    expect(find.text('→ 118 g'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('blend-ery-xyl-sugar-input')),
      '50',
    );
    await tester.pumpAndSettle();
    expect(find.text('→ 59 g'), findsOneWidget);
  });

  testWidgets('a flour mix carries no replace-sugar field', (tester) async {
    await pumpApp(tester);

    expect(
      find.byKey(const ValueKey('blend-bread-mix-sugar-input')),
      findsNothing,
    );
  });

  testWidgets('the mass toggle reaches composition, total and sugar label', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('toggle-mass-unit')));
    await tester.pumpAndSettle();

    expect(find.text('3.5 oz erythritol'), findsOneWidget);
    expect(find.text('4.9 oz erythritol'), findsOneWidget);
    expect(find.text('Total 7.1 oz'), findsNWidgets(2));
    expect(find.text('Total 35.3 oz'), findsOneWidget);
    expect(find.text('sugar oz'), findsNWidgets(2));

    await tester.enterText(
      find.byKey(const ValueKey('blend-ery-xyl-sugar-input')),
      '100',
    );
    await tester.pumpAndSettle();
    expect(find.text('→ 3335 g'), findsOneWidget);
  });

  testWidgets('the filter reaches blend names and component ids', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.enterText(find.byKey(const ValueKey('recipe-filter')), 'xyl');
    await tester.pumpAndSettle();
    expect(find.text('Erythritol xylitol'), findsOneWidget);
    expect(find.text('Half sugar swap'), findsNothing);
    expect(find.text('Sandwich loaf'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('recipe-filter')),
      'whole_wheat',
    );
    await tester.pumpAndSettle();
    expect(find.text('Bread mix'), findsOneWidget);
    expect(find.text('Erythritol xylitol'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('recipe-filter')), 'loaf');
    await tester.pumpAndSettle();
    expect(find.text('Sandwich loaf'), findsOneWidget);
    expect(find.text('blends'), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('recipe-filter')), '');
    await tester.pumpAndSettle();
    expect(find.text('Erythritol xylitol'), findsOneWidget);
  });

  testWidgets('a box without blends shows no divider', (tester) async {
    await pumpApp(tester, seedBlends: false);

    expect(find.text('blends'), findsNothing);
    expect(find.byType(BlendCard), findsNothing);
    expect(find.text('Butter cookies'), findsOneWidget);
  });

  testWidgets('blend cards dim while a recipe slider drags', (tester) async {
    await pumpApp(tester);
    final slider = tester.widget<Slider>(
      find.byKey(const ValueKey('cookies-slider')),
    );

    slider.onChangeStart!(36);
    slider.onChanged!(36);
    await tester.pump();

    final opacity = find
        .descendant(
          of: find.byType(BlendCard),
          matching: find.byType(AnimatedOpacity),
        )
        .first;
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0.55);

    tester
        .widget<Slider>(find.byKey(const ValueKey('cookies-slider')))
        .onChangeEnd!(36);
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
  });
}
