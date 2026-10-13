import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sqlite_test_setup.dart';

void main() {
  setUpAll(() {
    overrideSqliteForTests();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
      return const StandardMessageCodec().encodeMessage(
        '/tmp/opencode/bellenissimos-test',
      );
    });
  });

  testWidgets('diagnose edit flow', (tester) async {
    final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('editor-name')),
      'Butter cookies deluxe',
    );
    final saveKey = find.byKey(const ValueKey('editor-save'));
    await tester.ensureVisible(saveKey);
    await tester.pumpAndSettle();
    await tester.tap(saveKey);
    await tester.pumpAndSettle();
    debugPrint('SHEET OPEN: ${saveKey.evaluate().length}');
    debugPrint(
      'DELUXE TEXT: ${find.text('Butter cookies deluxe').evaluate().length}',
    );
    debugPrint('STORE NAME: ${store.byId('butter-cookies')!.name}');
    debugPrint(
      'SNACKBAR: ${find.text('Give the recipe a name and complete lines').evaluate().length}',
    );
  });
}
