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
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();
  }

  testWidgets('imports a schema.org recipe as a new card', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('import-recipe')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('import-json')),
      '{"@type": "Recipe", "name": "Sesame bread", "recipeYield": "1 loaf",'
      ' "recipeIngredient": ["400 g flour", "280 g water", "8 g salt"],'
      ' "recipeInstructions": ["mix", "bake"]}',
    );
    await tester.tap(find.byKey(const ValueKey('import-submit')));
    await tester.pumpAndSettle();

    expect(find.text('Sesame bread'), findsOneWidget);
    final imported = byId(store, 'sesame-bread')!;
    expect(imported.lines.length, 3);
    expect(imported.lines[0].quantity.amount, 400);
    expect(imported.steps, ['mix', 'bake']);
    expect(imported.createdAt, isNotNull);
    expect(store.all().length, 4);
  });

  testWidgets('malformed JSON keeps the dialog and shows the issue',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('import-recipe')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('import-json')),
      'not json at all',
    );
    await tester.tap(find.byKey(const ValueKey('import-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-submit')), findsOneWidget);
    expect(find.text('Malformed JSON'), findsOneWidget);
    expect(store.all().length, 3);
  });

  testWidgets('import issues are listed when the document is unusable',
      (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('import-recipe')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('import-json')),
      '{"@type": "Recipe", "name": "Empty"}',
    );
    await tester.tap(find.byKey(const ValueKey('import-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-submit')), findsOneWidget);
    expect(store.all().length, 3);
  });

  testWidgets('cancel closes the dialog without importing', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('import-recipe')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-json')),
      '{"@type": "Recipe", "name": "Cancelled cake",'
      ' "recipeYield": "1 cake", "recipeIngredient": ["200 g flour"]}',
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('import-submit')), findsNothing);
    expect(byId(store, 'cancelled-cake'), isNull);
    expect(store.all().length, 3);
  });
}
