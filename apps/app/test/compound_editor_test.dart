import 'package:bellenissimos_app/editor/compound_editor.dart';
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

YieldSpec yieldOf(Recipe recipe) => recipe.yield;

Recipe? byId(RecipeStore store, String id) => store.byId(id);

Recipe spongePart() => Recipe(
  id: 'sponge',
  name: 'Sponge',
  yield: const YieldSpec(count: 1),
  items: const [
    RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(300, Unit.g)),
  ],
);

/// [yield] stays out of async bodies.
Recipe editableDish() => Recipe.compound(
  id: 'torte',
  name: 'Torte',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(
    name: 'Torte',
    components: [
      ComponentRef(spongePart(), factor: 0.75),
      const RecipeLine(Ingredient('powdered_sugar'), Quantity(30, Unit.g)),
    ],
  ),
);

typedef LineShape = (String, double, Unit);

List<LineShape> lineShapes(Recipe recipe) => [
  for (final line in recipe.items.whereType<RecipeLine>())
    (line.ingredient.id, line.quantity.amount, line.quantity.unit),
];

/// [Recipe.yield] is a keyword in async bodies; build dishes out of line.
Recipe blendDish(Blend blend) => Recipe.compound(
  id: 'cake',
  name: 'Cake',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(
    name: 'Cake',
    components: [
      ComponentRef(spongePart(), factor: 1),
      BlendLine(blend, 40),
    ],
  ),
);

Recipe gramsDish() => Recipe.compound(
  id: 'loaf-cake',
  name: 'Loaf cake',
  yield: const YieldSpec(totalGrams: 900),
  tree: RecipeTree(
    name: 'Loaf cake',
    components: [ComponentRef(spongePart(), factor: 1)],
  ),
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

  Future<void> pumpHarness(
    WidgetTester tester, {
    Recipe? recipe,
    BlendStore? blends,
  }) async {
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
                  popped = await showCompoundEditor(
                    context,
                    store,
                    blends: blends,
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

  Future<void> addPart(WidgetTester tester, String recipeId) async {
    await tester.tap(find.byKey(const ValueKey('editor-add-part')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('compound-pick-$recipeId')));
    await tester.pumpAndSettle();
  }

  String pickText(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byKey(ValueKey('editor-comp-$index-pick')))
      .controller!
      .text;

  testWidgets('the add sheet lists four kinds and compound opens its editor', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('add-choice-recipe')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-sweetener')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-flour')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-choice-compound')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-choice-compound')));
    await tester.pumpAndSettle();

    expect(find.text('New compound dish'), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-add-part')), findsOneWidget);
    expect(find.byKey(const ValueKey('editor-add-line')), findsOneWidget);
  });

  testWidgets('creates a two-batter + filling compound through the add sheet', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('add-recipe')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-choice-compound')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Torte');
    await addPart(tester, 'butter-cookies');
    await addPart(tester, 'butter-cookies');
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-factor')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-ingredient')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-amount')),
      '30',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(byId(store, 'torte'), isNotNull);
    expect(find.text('Torte'), findsOneWidget);
  });

  testWidgets('builds the tree in assembly order with caller-set stamps', (
    tester,
  ) async {
    await pumpApp(tester);
    final partBefore = byId(store, 'butter-cookies')!;
    final beforeShapes = lineShapes(partBefore);

    await pumpHarness(tester);

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Torte');
    await addPart(tester, 'butter-cookies');
    expect(pickText(tester, 0), 'Butter cookies');
    await addPart(tester, 'butter-cookies');
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-factor')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-ingredient')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-amount')),
      '30',
    );
    await tester.pumpAndSettle();
    expect(find.text('3 parts'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = popped!;
    expect(saved.isCompound, isTrue);
    final components = saved.items;
    expect(components.length, 3);
    final first = components[0] as ComponentRef;
    expect(first.recipe.id, 'butter-cookies');
    expect(first.factor, 1);
    final second = components[1] as ComponentRef;
    expect(second.factor, 2);
    final leaf = components[2] as RecipeLine;
    expect(leaf.ingredient.id, 'cocoa');
    expect(leaf.quantity.amount, 30);
    expect(leaf.quantity.unit, Unit.g);
    expect(yieldOf(saved).count, 1);
    expect(saved.createdAt, isNotNull);
    expect(saved.updatedAt, isNotNull);

    final partAfter = byId(store, 'butter-cookies')!;
    expect(lineShapes(partAfter), beforeShapes);
    expect(yieldOf(partAfter).count, yieldOf(partBefore).count);
  });

  testWidgets('the readout sums resolvable parts and never guesses', (
    tester,
  ) async {
    await pumpApp(tester);
    await pumpHarness(tester);

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Kg dish');
    await addPart(tester, 'sandwich-loaf');
    await tester.pumpAndSettle();
    expect(find.text('1 part · ≈ 0.9 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-ingredient')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-amount')),
      '30',
    );
    await tester.pumpAndSettle();
    expect(find.text('2 parts · ≈ 0.9 kg'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-ingredient')),
      'mystery',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-2-amount')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('editor-comp-2-unit')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('piece').last);
    await tester.pumpAndSettle();
    expect(find.text('3 parts'), findsOneWidget);
  });

  testWidgets('editing a compound restores its rows and factors', (
    tester,
  ) async {
    await pumpApp(tester);
    await pumpHarness(tester, recipe: editableDish());

    expect(find.text('Compound dish'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-name')))
          .controller!
          .text,
      'Torte',
    );
    expect(pickText(tester, 0), 'Sponge');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-comp-0-factor')))
          .controller!
          .text,
      '0.75',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('editor-comp-1-ingredient')),
          )
          .controller!
          .text,
      'powdered_sugar',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = popped!;
    final components = saved.items;
    expect(components.length, 2);
    final ref = components[0] as ComponentRef;
    expect(ref.recipe.id, 'sponge');
    expect(ref.factor, 0.75);
    expect((components[1] as RecipeLine).ingredient.id, 'powdered_sugar');
  });

  testWidgets('incomplete drafts are rejected with a message', (tester) async {
    await pumpApp(tester);
    await pumpHarness(tester);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(find.text('Give the dish a name and complete rows'), findsOneWidget);
    expect(store.all().length, 3);
  });

  testWidgets('rows can be removed and the sheet dismissed', (tester) async {
    await pumpApp(tester);
    await pumpHarness(tester);

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Torte');
    await addPart(tester, 'butter-cookies');
    await tester.tap(find.byKey(const ValueKey('editor-add-line')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-ingredient')),
      'cocoa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-1-amount')),
      '30',
    );

    await tester.tap(find.byKey(const ValueKey('editor-comp-1-remove')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('editor-comp-1-ingredient')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    expect(popped!.items.length, 1);
    expect(store.all().length, 4);

    await pumpHarness(tester);
    await addPart(tester, 'sandwich-loaf');
    await tester.tap(find.byKey(const ValueKey('editor-comp-0-remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-comp-0-pick')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();
    expect(popped, isNull);
    expect(find.text('Give the dish a name and complete rows'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(popped, isNull);
    expect(find.byKey(const ValueKey('editor-save')), findsNothing);
    expect(store.all().length, 4);
  });

  testWidgets('a restored part row can be re-picked from the field', (
    tester,
  ) async {
    await pumpApp(tester);
    await pumpHarness(tester, recipe: editableDish());

    await tester.tap(find.byKey(const ValueKey('editor-comp-0-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compound-pick-sandwich-loaf')));
    await tester.pumpAndSettle();

    expect(pickText(tester, 0), 'Sandwich loaf');
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final ref = popped!.items.first as ComponentRef;
    expect(ref.recipe.id, 'sandwich-loaf');
    expect(ref.factor, 0.75);
  });

  testWidgets('editing a stored compound opens the compound editor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    store.upsert(editableDish());
    popped = null;
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menu-torte')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-torte')));
    await tester.pumpAndSettle();

    expect(find.text('Compound dish'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-name')))
          .controller!
          .text,
      'Torte',
    );
    expect(pickText(tester, 0), 'Sponge');
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-comp-0-factor')))
          .controller!
          .text,
      '0.75',
    );
  });

  BlendStore blendLibrary() {    final blends = BlendStore.inMemory(store);
    blends.upsertBlend(
      BlendRecord(
        blend: SweetenerBlend(
          id: 'berry-1',
          name: 'Berry mix',
          grams: {const Ingredient('sugar'): 100},
          sweetnessPerGram: {const Ingredient('sugar'): 0.7},
        ),
      ),
    );
    return blends;
  }

  Future<void> addBlend(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('editor-add-blend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compound-pick-blend-berry-1')));
    await tester.pumpAndSettle();
  }

  testWidgets('a blend row saves its grams through the picker', (
    tester,
  ) async {
    await pumpApp(tester);
    final library = blendLibrary();
    await pumpHarness(tester, blends: library);

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Cake');
    await addBlend(tester);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('editor-comp-0-blend-grams')),
          )
          .controller!
          .text,
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('editor-comp-0-blend-grams')),
      '40',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final blend = popped!.items.single as BlendLine;
    expect(blend.blend.id, 'berry-1');
    expect(blend.grams, 40);
  });

  testWidgets('editing restores blend rows with their grams', (
    tester,
  ) async {
    await pumpApp(tester);
    final library = blendLibrary();
    final dish = blendDish(library.byId('berry-1')!.blend);
    await pumpHarness(tester, blends: library, recipe: dish);

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-comp-1-blend')))
          .controller!
          .text,
      'Berry mix',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('editor-comp-1-blend-grams')),
          )
          .controller!
          .text,
      '40',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final blend = popped!.items[1] as BlendLine;
    expect(blend.blend.id, 'berry-1');
    expect(blend.grams, 40);
  });

  testWidgets('toggling the yield mode saves a grams yield', (
    tester,
  ) async {
    await pumpApp(tester);
    await pumpHarness(tester);

    await tester.enterText(find.byKey(const ValueKey('editor-name')), 'Loaf');
    await tester.tap(find.text('grams'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-compound-makes')),
      '900',
    );
    await addPart(tester, 'sandwich-loaf');

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(yieldOf(popped!).count, isNull);
    expect(yieldOf(popped!).totalGrams, 900);
  });

  testWidgets('a blend row can be re-picked from its field', (
    tester,
  ) async {
    await pumpApp(tester);
    final library = blendLibrary();
    await pumpHarness(
      tester,
      blends: library,
      recipe: blendDish(library.byId('berry-1')!.blend),
    );

    await tester.tap(find.byKey(const ValueKey('editor-comp-1-blend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('compound-pick-blend-berry-1')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('editor-comp-1-blend')))
          .controller!
          .text,
      'Berry mix',
    );
    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final blend = popped!.items[1] as BlendLine;
    expect(blend.blend.id, 'berry-1');
  });

  testWidgets('a blend row can be removed before saving', (
    tester,
  ) async {
    await pumpApp(tester);
    final library = blendLibrary();
    await pumpHarness(
      tester,
      blends: library,
      recipe: blendDish(library.byId('berry-1')!.blend),
    );

    await tester.tap(find.byKey(const ValueKey('editor-comp-1-remove')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(popped!.items, hasLength(1));
    expect(popped!.items.single, isA<ComponentRef>());
  });

  testWidgets('a grams yield restores grams mode and survives save', (
    tester,
  ) async {
    await pumpApp(tester);
    await pumpHarness(tester, recipe: gramsDish());

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('editor-compound-makes')),
          )
          .controller!
          .text,
      '900',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(yieldOf(popped!).count, isNull);
    expect(yieldOf(popped!).totalGrams, 900);
  });
}
