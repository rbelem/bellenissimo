import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';


/// [Recipe.yield] is a keyword in async bodies; read it out of line.
YieldSpec yieldOf(Recipe recipe) => recipe.yield;

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
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('creates a recipe through the editor', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('add-recipe')));
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
    expect(saved.lines.single.ingredient.id, 'cocoa');
    expect(saved.lines.single.quantity.amount, 30);
    expect(saved.lines.single.quantity.unit, Unit.g);
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
    expect(variant.lines[1].ingredient.id, 'walnut');
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
      scrollable: find.byType(Scrollable).first,
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

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editor-save')), findsOneWidget);
    expect(
      find.text('Give the recipe a name and complete lines'),
      findsOneWidget,
    );
    expect(store.all().length, 3);
  });
}
