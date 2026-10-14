import 'dart:io';

import 'package:bellenissimos_app/export/box_dialog.dart';
import 'package:bellenissimos_app/export/box_io.dart';
import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/blend_store.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_app/theme.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _cake() => Recipe(
  id: 'fudgy-cake',
  name: 'Fudgy cake',
  yield: const YieldSpec(count: 8),
  lines: [
    RecipeLine(
      const Ingredient('cocoa', gramsPerMl: 0.42),
      const Quantity(30, Unit.g),
    ),
  ],
);

Future<void> _openPage(WidgetTester tester, RecipeStore store) async {
  await tester.pumpWidget(app.BellenissimosApp(store: store));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('box-actions')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export writes the box file and reports the path', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('box-dialog-test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await tester.pumpWidget(
      MaterialApp(
        theme: recipeBoxLight,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showBoxDialog(
                  context,
                  store,
                  blends: BlendStore.inMemory(store),
                  supportDir: () async => dir,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('box-export')));
    await tester.pumpAndSettle();

    final files = dir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));
    final doc = files.single.readAsStringSync();
    expect(doc, contains('Butter cookies'));
    expect(doc, contains('"version": 2'));
    expect(find.textContaining('Box exported'), findsOneWidget);
  });

  testWidgets('import merge adds the incoming recipes', (tester) async {
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await _openPage(tester, store);
    await tester.enterText(
      find.byKey(const ValueKey('box-paste')),
      encodeBox([_cake()], const []),
    );
    await tester.tap(find.byKey(const ValueKey('box-import')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('recipe-filter')),
      'fudgy',
    );
    await tester.pumpAndSettle();
    expect(find.text('Fudgy cake'), findsOneWidget);
    expect(find.textContaining('Imported 1 recipe'), findsOneWidget);
  });

  testWidgets('a junk entry is skipped with an issue, good entries import', (
    tester,
  ) async {
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await _openPage(tester, store);
    final doc = encodeBox([
      _cake(),
    ], const []).replaceFirst('"recipes": [', '"recipes": [42,');
    await tester.enterText(find.byKey(const ValueKey('box-paste')), doc);
    await tester.tap(find.byKey(const ValueKey('box-import')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('recipe-filter')),
      'fudgy',
    );
    await tester.pumpAndSettle();
    expect(find.text('Fudgy cake'), findsOneWidget);
    expect(
      find.textContaining('Recipe entry is not an object'),
      findsOneWidget,
    );
  });

  testWidgets('a malformed paste reports the issue and changes nothing', (
    tester,
  ) async {
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await _openPage(tester, store);
    await tester.enterText(find.byKey(const ValueKey('box-paste')), 'zzz');
    await tester.tap(find.byKey(const ValueKey('box-import')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Malformed JSON'), findsOneWidget);
    expect(find.text('Butter cookies'), findsOneWidget);
  });

  testWidgets('replace mode swaps the whole box', (tester) async {
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await _openPage(tester, store);
    await tester.tap(find.text('replace'));
    await tester.enterText(
      find.byKey(const ValueKey('box-paste')),
      encodeBox([_cake()], const []),
    );
    await tester.tap(find.byKey(const ValueKey('box-import')));
    await tester.pumpAndSettle();

    expect(find.text('Fudgy cake'), findsOneWidget);
    expect(find.text('Butter cookies'), findsNothing);
  });

  testWidgets('the sheet closes without acting', (tester) async {
    final store = RecipeStore.inMemory()..ensureSeeded([butterCookies]);
    await _openPage(tester, store);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('box-export')), findsNothing);
  });
}
