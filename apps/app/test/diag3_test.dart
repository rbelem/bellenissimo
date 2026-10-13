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

  testWidgets('diagnose unit toggle', (tester) async {
    final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    await tester.pumpWidget(app.BellenissimosApp(store: store));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle-mass-unit')));
    await tester.pumpAndSettle();
    final texts = find
        .byType(Text)
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .where((t) => t != null && t.contains('flour'))
        .toList();
    debugPrint('FLOUR TEXTS: $texts');
  });
}
