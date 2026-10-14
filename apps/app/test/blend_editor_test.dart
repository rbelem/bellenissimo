import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/blend_store.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BlendRecord _eryXyl() => BlendRecord(
  blend: SweetenerBlend(
    id: 'ery-xyl',
    name: 'Erythritol xylitol',
    grams: {
      seedIngredients['erythritol'] ?? const Ingredient('erythritol'): 100,
      seedIngredients['xylitol'] ?? const Ingredient('xylitol'): 100,
    },
    sweetnessPerGram: {
      const Ingredient('erythritol'): 0.7,
      const Ingredient('xylitol'): 1.0,
    },
  ),
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 2),
);

BlendRecord _breadMix() => BlendRecord(
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

String? attributeText(WidgetTester tester, int index) => tester
    .widget<TextField>(find.byKey(ValueKey('editor-line-attribute-$index')))
    .controller
    ?.text;

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

  Future<void> pumpApp(
    WidgetTester tester, {
    bool seedBlends = true,
    Recipe? extraRecipe,
  }) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    if (extraRecipe != null) store.upsert(extraRecipe);
    blends = BlendStore.inMemory(store);
    if (seedBlends) blends.upsertAll([_eryXyl(), _breadMix()]);
    await tester.pumpWidget(
      app.BellenissimosApp(store: store, blendStore: blends),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openEditor(WidgetTester tester, String choiceKey) async {
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(choiceKey)));
    await tester.pumpAndSettle();
  }

  testWidgets('the FAB offers recipe, sweetener and flour choices', (
    tester,
  ) async {
    await pumpApp(tester, seedBlends: false);

    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-choice-recipe')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-sweetener')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-flour')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-steps')), findsOneWidget);
  });

  testWidgets('creates a sweetener blend with seeded attributes', (
    tester,
  ) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    expect(find.text('New sweetener blend'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Ery xyl',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'erythritol',
    );
    await tester.pumpAndSettle();
    expect(attributeText(tester, 0), '0.7');
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '100',
    );

    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-1')),
      'xylitol',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-1')),
      '100',
    );
    await tester.pumpAndSettle();
    expect(attributeText(tester, 1), '1');
    expect(
      find.text('sweetness ×0.85 of sugar · replaces 100 g sugar with 118 g'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = blends.byId('ery-xyl')!;
    expect(saved.blend.name, 'Ery xyl');
    expect(saved.blend.totalGrams, 200);
    expect(
      (saved.blend as SweetenerBlend).sucroseEquivalentPerGram,
      closeTo(0.85, 1e-9),
    );
    expect(find.text('Ery xyl'), findsOneWidget);
    expect(find.text('Total 200 g'), findsOneWidget);
  });

  testWidgets('creates a flour mix with the hydration readout', (tester) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-flour');

    expect(find.text('New flour mix'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Strong white',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'bread_flour',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '400',
    );
    await tester.pumpAndSettle();
    expect(attributeText(tester, 0), '13');
    expect(
      find.text('protein 13.0 % · bread hydration ≈ 67 %'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(blends.byId('strong-white'), isNotNull);
    expect(find.text('protein 13.0 %'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blend-strong-white-sugar-input')),
      findsNothing,
    );
  });

  testWidgets('an unknown ingredient defaults the attribute to the anchor', (
    tester,
  ) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'moon_powder',
    );
    await tester.pumpAndSettle();

    expect(attributeText(tester, 0), '1');
  });

  testWidgets('an incomplete blend is rejected with a message', (tester) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(
      find.text('Give the blend a name and complete lines'),
      findsOneWidget,
    );
    expect(blends.all(), isEmpty);
  });

  testWidgets('a zero sweetness attribute is rejected', (tester) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Flat');
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'sugar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-attribute-0')),
      '0',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-blend-readout')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(blends.all(), isEmpty);
  });

  testWidgets('a duplicate ingredient is rejected', (tester) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Twin');
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'sugar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-1')),
      'sugar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-1')),
      '50',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-blend-readout')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(blends.all(), isEmpty);
  });

  testWidgets('a weak draft shows the editor note; lines can be removed '
      'and the sheet dismissed', (tester) async {
    await pumpApp(tester, seedBlends: false);
    await openEditor(tester, 'add-choice-sweetener');

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Weak');
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'erythritol',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '140',
    );
    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-1')),
      'sugar',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-1')),
      '60',
    );
    await tester.pumpAndSettle();

    expect(
      find.text('sweetness ×0.79 of sugar · replaces 100 g sugar with 127 g'),
      findsOneWidget,
    );
    expect(
      find.text("won't bulk like sugar — structure will shift"),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('editor-line-remove-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-line-remove-1')), findsNothing);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-save')), findsNothing);
    expect(blends.all(), isEmpty);
  });

  testWidgets('editing a flour mix keeps the kind and restores the parts',
      (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('menu-bread-mix')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-bread-mix')));
    await tester.pumpAndSettle();

    expect(find.text('Flour mix'), findsOneWidget);
    expect(attributeText(tester, 0), '10');
    expect(attributeText(tester, 1), '14');

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = blends.byId('bread-mix')!;
    expect(saved.blend.name, 'Bread mix');
    expect(saved.createdAt, isNotNull);
  });

  testWidgets('editing keeps the id and the created stamp', (tester) async {    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('menu-ery-xyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-ery-xyl')));
    await tester.pumpAndSettle();

    expect(find.text('Sweetener blend'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-name')))
          .controller!
          .text,
      'Erythritol xylitol',
    );
    expect(attributeText(tester, 0), '0.7');

    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Ery xyl two',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = blends.byId('ery-xyl')!;
    expect(saved.blend.name, 'Ery xyl two');
    expect(saved.createdAt, DateTime(2026, 3, 1));
    expect(saved.updatedAt, isNot(DateTime(2026, 3, 2)));
    expect(find.text('Ery xyl two'), findsOneWidget);
  });

  testWidgets('deleting a referenced blend warns and keeps the recipe', (
    tester,
  ) async {
    final record = _eryXyl();
    await pumpApp(
      tester,
      extraRecipe: butterCookies.copyWith(
        id: 'blend-cookies',
        name: 'Blend cookies',
        blends: [BlendLine(record.blend, 120)],
      ),
    );

    await tester.tap(find.byKey(const ValueKey('menu-ery-xyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-delete-ery-xyl')));
    await tester.pumpAndSettle();

    expect(find.text('Used in Blend cookies — delete anyway?'), findsOneWidget);

    await tester.tap(find.text('Keep'));
    await tester.pumpAndSettle();
    expect(blends.byId('ery-xyl'), isNotNull);
    expect(find.text('Erythritol xylitol'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('menu-ery-xyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-delete-ery-xyl')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(blends.byId('ery-xyl'), isNull);
    expect(find.text('Erythritol xylitol'), findsNothing);
    final attached = store.byId('blend-cookies')!.blends.single;
    expect(attached.grams, 120);
    expect(attached.blend.name, 'Erythritol xylitol');
    expect(find.text('Blend cookies'), findsOneWidget);
  });

  testWidgets('deleting an unreferenced blend skips the warning', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('menu-bread-mix')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-delete-bread-mix')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Used in'), findsNothing);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(blends.byId('bread-mix'), isNull);
    expect(find.text('Bread mix'), findsNothing);
  });

  testWidgets('the card menu can be dismissed without acting', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('menu-ery-xyl')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('menu-edit-ery-xyl')), findsNothing);
    expect(blends.byId('ery-xyl'), isNotNull);
  });
}
