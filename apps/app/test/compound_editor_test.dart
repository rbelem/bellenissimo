import 'package:bellenissimos_app/editor/compound_editor.dart';
import 'package:bellenissimos_app/main.dart' as app;
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
  lines: const [
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
      const ComponentLeaf(
        RecipeLine(Ingredient('powdered_sugar'), Quantity(30, Unit.g)),
      ),
    ],
  ),
);

typedef LineShape = (String, double, Unit);

List<LineShape> lineShapes(Recipe recipe) => [
  for (final line in recipe.lines)
    (line.ingredient.id, line.quantity.amount, line.quantity.unit),
];

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

  Future<void> pumpHarness(WidgetTester tester, {Recipe? recipe}) async {
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
                  popped = await showCompoundEditor(context, store, recipe: recipe);
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
    final components = saved.tree!.components;
    expect(components.length, 3);
    final first = components[0] as ComponentRef;
    expect(first.recipe.id, 'butter-cookies');
    expect(first.factor, 1);
    final second = components[1] as ComponentRef;
    expect(second.factor, 2);
    final leaf = components[2] as ComponentLeaf;
    expect(leaf.line.ingredient.id, 'cocoa');
    expect(leaf.line.quantity.amount, 30);
    expect(leaf.line.quantity.unit, Unit.g);
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
    final components = saved.tree!.components;
    expect(components.length, 2);
    final ref = components[0] as ComponentRef;
    expect(ref.recipe.id, 'sponge');
    expect(ref.factor, 0.75);
    expect((components[1] as ComponentLeaf).line.ingredient.id,
        'powdered_sugar');
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
}
