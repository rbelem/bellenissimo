import 'package:bellenissimos_app/editor/recipe_editor.dart';
import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_app/theme.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';


/// [Recipe.yield] is a keyword in async bodies; read it out of line.
YieldSpec yieldOf(Recipe recipe) => recipe.yield;

Recipe? byId(RecipeStore store, String id) => store.byId(id);

/// A recipe with a custom leavening line; keeps the [Recipe.yield]
/// keyword out of async bodies.
Recipe levainLoaf() => Recipe(
  id: 'levain-loaf',
  name: 'Levain loaf',
  yield: YieldSpec(totalGrams: 900),
  items: [
    RecipeLine(
      const Ingredient('fresh_yeast', scalingExponent: 0.7),
      const Quantity(20, Unit.g),
    ),
  ],
);

/// A plain recipe holding a recipe part; keeps [Recipe.yield] out of
/// async bodies.
Recipe cookieStack(Recipe part) => Recipe(
  id: 'cookie-stack',
  name: 'Cookie stack',
  yield: const YieldSpec(count: 1),
  items: [
    RecipeLine(
      seedIngredients['flour']!,
      const Quantity(100, Unit.g),
    ),
    ComponentRef(part, factor: 0.5),
  ],
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
  Recipe? popped;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    popped = null;
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPlainHarness(WidgetTester tester, {Recipe? recipe}) async {
    tester.view.physicalSize = const Size(1170, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    popped = null;
    await tester.pumpWidget(
      MaterialApp(
        theme: recipeBoxLight,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  popped = await showRecipeEditor(
                    context,
                    store,
                    recipe: recipe,
                  );
                },
                child: const Text('open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a recipe through the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Chocolate cake',
    );
    await tester.tap(find.text('grams'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-yield-value')),
      '400',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-steps')),
      'mix everything\nbake at 180 C',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('Chocolate cake'), findsOneWidget);
    expect(find.text('Target: 400 g'), findsOneWidget);
    final saved = byId(store, 'chocolate-cake')!;
    expect(yieldOf(saved).totalGrams, 400);
    expect(yieldOf(saved).count, isNull);
    expect(saved.items.whereType<RecipeLine>().toList().single.ingredient.id, 'cocoa');
    expect(saved.items.whereType<RecipeLine>().toList().single.quantity.amount, 30);
    expect(saved.items.whereType<RecipeLine>().toList().single.quantity.unit, Unit.g);
    expect(saved.steps, ['mix everything', 'bake at 180 C']);
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);
  });

  testWidgets('edits an existing recipe and bumps updatedAt', (tester) async {
    await pumpApp(tester);
    final original = byId(store, 'butter-cookies')!;
    final createdAt = original.createdAt;
    final updatedAtBefore = original.updatedAt;

    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-butter-cookies')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-name')))
          .controller!
          .text,
      'Butter cookies',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Butter cookies deluxe',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.text('Butter cookies deluxe'), findsOneWidget);
    final edited = byId(store, 'butter-cookies')!;
    expect(edited.name, 'Butter cookies deluxe');
    expect(edited.createdAt, createdAt);
    expect(edited.updatedAt, isNot(updatedAtBefore));
  });

  testWidgets('derives a variant from a card menu', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-variant-butter-cookies')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Nutty cookies',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-1')),
      'walnut',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final variant = byId(store, 'nutty-cookies')!;
    expect(variant.parentId, 'butter-cookies');
    expect(yieldOf(variant).count, 24);
    expect(variant.items.whereType<RecipeLine>().toList()[1].ingredient.id, 'walnut');
    expect(find.text('Nutty cookies'), findsOneWidget);
    expect(find.text('variant of Butter cookies'), findsNWidgets(2));
    expect(find.text('VARIANT'), findsNothing);
    expect(find.text('Makes 24 cookies'), findsNWidgets(3));
    expect(find.text('Makes 24 pieces'), findsNothing);
  });

  testWidgets('deleting a parent leaves its variants renderable',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-delete-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(byId(store, 'butter-cookies'), isNull);
    expect(find.text('Egg-free butter cookies'), findsOneWidget);
    expect(find.text('variant of Butter cookies'), findsNothing);
  });

  testWidgets('a variant can itself spawn a variant', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('menu-egg-free-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('menu-variant-egg-free-cookies')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Fudgy cookies',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(byId(store, 'fudgy-cookies')!.parentId, 'egg-free-cookies');
    expect(find.text('variant of Egg-free butter cookies'), findsOneWidget);
  });

  testWidgets('deletes a recipe after confirmation', (tester) async {
    await pumpApp(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('menu-sandwich-loaf')),
      160,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-sandwich-loaf')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-delete-sandwich-loaf')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Sandwich loaf'), findsNothing);
    expect(byId(store, 'sandwich-loaf'), isNull);
    expect(store.all().length, 2);
  });

  testWidgets('incomplete recipes are rejected with a message',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(
      find.text('Give the recipe a name and complete lines'),
      findsOneWidget,
    );
    expect(store.all().length, 3);
  });

  testWidgets('adds an ingredient line through the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Two-liner',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-1')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-1')),
      '30',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = byId(store, 'two-liner')!;
    expect(saved.items.whereType<RecipeLine>().toList().length, 2);
    expect(saved.items.whereType<RecipeLine>().toList()[0].ingredient.id, 'flour');
    expect(saved.items.whereType<RecipeLine>().toList()[1].ingredient.id, 'cocoa');
    expect(find.text('30 g cocoa'), findsOneWidget);
  });

  testWidgets('removes an ingredient line', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-butter-cookies')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-line-remove-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-line-remove-3')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = byId(store, 'butter-cookies')!;
    expect(saved.items.whereType<RecipeLine>().toList().length, 3);
    expect(
      saved.items.whereType<RecipeLine>().toList().map((line) => line.ingredient.id),
      ['flour', 'butter', 'sugar'],
    );
    expect(find.text('1 piece egg'), findsNothing);
  });

  testWidgets('closing the editor discards the draft', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Ghost cake',
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsNothing);
    expect(byId(store, 'ghost-cake'), isNull);
    expect(store.all().length, 3);
  });

  testWidgets('switches a line unit to millilitres', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Milk pudding',
    );
    await tester.tap(find.byKey(const ValueKey('editor-line-unit-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ml'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-ingredient-0')),
      'milk',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-line-amount-0')),
      '300',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = byId(store, 'milk-pudding')!;
    expect(saved.items.whereType<RecipeLine>().toList().single.ingredient.id, 'milk');
    expect(saved.items.whereType<RecipeLine>().toList().single.quantity.unit, Unit.ml);
    expect(saved.items.whereType<RecipeLine>().toList().single.quantity.amount, 300);
    expect(find.text('300 ml milk'), findsOneWidget);
  });

  group('custom ingredient scaling', () {
    testWidgets('a custom ingredient gains an exponent field and saves it', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('add-recipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('editor-name')),
        'Sourdough',
      );
      await tester.tap(find.text('grams'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor-yield-value')),
        '900',
      );
      await tester.enterText(
        find.byKey(const ValueKey('editor-line-ingredient-0')),
        'fresh_yeast',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor-line-amount-0')),
        '20',
      );
      expect(
        find.byKey(const ValueKey('editor-line-exponent-0')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('editor-line-exponent-0')),
        '0.7',
      );
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      final saved = byId(store, 'sourdough')!;
      expect(saved.items.whereType<RecipeLine>().toList().single.ingredient.scalingExponent, 0.7);
    });

    testWidgets('an empty exponent saves a linear custom ingredient', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('add-recipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('editor-name')),
        'Cocoa bar',
      );
      await tester.tap(find.text('grams'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor-yield-value')),
        '200',
      );
      await tester.enterText(
        find.byKey(const ValueKey('editor-line-ingredient-0')),
        'cocoa_nibs',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor-line-amount-0')),
        '80',
      );
      expect(
        find.byKey(const ValueKey('editor-line-exponent-0')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      final saved = byId(store, 'cocoa-bar')!;
      expect(saved.items.whereType<RecipeLine>().toList().single.ingredient.scalingExponent, isNull);
    });

    testWidgets('a seed ingredient shows no exponent field', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('add-recipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('editor-line-ingredient-0')),
        'flour',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('editor-line-exponent-0')), findsNothing);
    });

    testWidgets('editing restores a saved custom exponent', (tester) async {
      tester.view.physicalSize = const Size(1170, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      store.upsert(levainLoaf());
      await tester.pumpWidget(app.BellenissimosApp(store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-levain-loaf')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-edit-levain-loaf')));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('editor-line-exponent-0')),
            )
            .controller!
            .text,
        '0.7',
      );
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(
        (byId(store, 'levain-loaf')!.items.single as RecipeLine).ingredient.scalingExponent,
        0.7,
      );
    });
  });

  group('recipe parts', () {
    testWidgets('attaching a recipe saves a ref with its factor', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const ValueKey('add-recipe')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-choice-recipe')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('editor-name')),
        'Cookie stack',
      );
      await tester.tap(find.byKey(const ValueKey('editor-attach-recipe')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('attach-recipe-butter-cookies')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('editor-attached-factor-0')),
        '2',
      );
      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      final saved = byId(store, 'cookie-stack')!;
      expect(saved.isCompound, isTrue);
      final ref = saved.items.last as ComponentRef;
      expect(ref.recipe.id, 'butter-cookies');
      expect(ref.factor, 2);
      expect(find.text('Butter cookies'), findsWidgets);
    });

    testWidgets('removing a recipe row drops the ref', (tester) async {
      await pumpApp(tester);
      await pumpPlainHarness(
        tester,
        recipe: cookieStack(store.byId('butter-cookies')!),
      );

      await tester.tap(
        find.byKey(const ValueKey('editor-attached-recipe-remove-0')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      expect(popped!.isCompound, isFalse);
      expect(popped!.items, hasLength(1));
      expect(popped!.items.single, isA<RecipeLine>());
    });

    testWidgets('the plain editor restores ref rows instead of dropping them',
        (tester) async {
      await pumpApp(tester);
      await pumpPlainHarness(
        tester,
        recipe: cookieStack(store.byId('butter-cookies')!),
      );

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('editor-attached-factor-0')),
            )
            .controller!
            .text,
        '0.5',
      );

      await tester.tap(find.byKey(const ValueKey('editor-save')));
      await tester.pumpAndSettle();

      final ref = popped!.items[1] as ComponentRef;
      expect(ref.recipe.id, 'butter-cookies');
      expect(ref.factor, 0.5);
      expect(popped!.items[0], isA<RecipeLine>());
    });

    testWidgets('editing restores recipe rows with their factors', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      store.upsert(cookieStack(store.byId('butter-cookies')!));
      await tester.pumpWidget(app.BellenissimosApp(store: store));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('menu-cookie-stack')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('menu-edit-cookie-stack')));
      await tester.pumpAndSettle();

      expect(find.text('Compound dish'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('editor-comp-1-factor')),
            )
            .controller!
            .text,
        '0.5',
      );
    });
  });
}
