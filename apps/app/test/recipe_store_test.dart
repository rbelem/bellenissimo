import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sqlite_test_setup.dart';

Recipe _variant() => butterCookies.copyWith(
      id: 'test-variant',
      parentId: 'butter-cookies',
      name: 'Test variant',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 2),
    );

void main() {
  setUpAll(overrideSqliteForTests);

  group('RecipeCodec', () {
    test('roundtrips every recipe field', () {
      final restored = RecipeCodec.decodeDoc(
        RecipeCodec.encodeDoc(eggFreeCookies),
      );
      expect(restored.id, 'egg-free-cookies');
      expect(restored.parentId, 'butter-cookies');
      expect(restored.name, 'Egg-free butter cookies');
      expect(restored.yield.count, 24);
      expect(restored.createdAt, DateTime(2026, 2, 1, 14));
      expect(restored.updatedAt, DateTime(2026, 2, 3, 9, 30));
      expect(restored.steps, eggFreeCookies.steps);
      expect(restored.lines.length, 4);
      expect(restored.lines[0].ingredient.id, 'flour');
      expect(restored.lines[0].quantity.amount, 250);
      expect(restored.lines[0].quantity.unit, Unit.g);
      expect(restored.lines[3].ingredient.id, 'applesauce');
    });

    test('roundtrips a mass-only yield and undated recipe', () {
      final restored = RecipeCodec.decodeDoc(
        RecipeCodec.encodeDoc(sandwichLoaf),
      );
      expect(restored.yield.count, isNull);
      expect(restored.yield.totalGrams, 900);
      expect(restored.createdAt, DateTime(2026, 1, 16, 8));
      expect(restored.lines[1].ingredient.gramsPerMl, 1.0);
    });

    test('keeps conversion data on ingredients', () {
      final restored = RecipeCodec.decodeDoc(
        RecipeCodec.encodeDoc(butterCookies),
      );
      final eggLine =
          restored.lines.firstWhere((l) => l.ingredient.id == 'egg');
      expect(eggLine.ingredient.gramsPerPiece, 50);
      expect(eggLine.ingredient.roundingStep, 0.5);
      expect(eggLine.quantity.unit, Unit.piece);
    });

    test('roundtrips a recipe without id or lineage', () {
      const adHoc = Recipe(
        name: 'ad hoc',
        yield: YieldSpec(count: 1),
        lines: [],
      );
      final restored = RecipeCodec.decodeDoc(RecipeCodec.encodeDoc(adHoc));
      expect(restored.id, isNull);
      expect(restored.parentId, isNull);
      expect(restored.lines, isEmpty);
    });
  });

  group('RecipeStore', () {
    late RecipeStore store;

    setUp(() => store = RecipeStore.inMemory());

    test('starts empty and seeds once', () {
      expect(store.all(), isEmpty);
      store.ensureSeeded(seedRecipes);
      expect(store.all().length, 3);
      store.ensureSeeded(seedRecipes);
      expect(store.all().length, 3);
    });

    test('seeds preserve every field', () {
      store.ensureSeeded(seedRecipes);
      final loaf = store.byId('sandwich-loaf')!;
      expect(loaf.yield.totalGrams, 900);
      expect(loaf.lines.length, 3);
      expect(loaf.steps.length, 4);
    });

    test('byId returns null for unknown ids', () {
      expect(store.byId('nope'), isNull);
    });

    test('upsert appends new recipes in insertion order', () {
      store.ensureSeeded(seedRecipes);
      store.upsert(_variant());
      final ids = store.all().map((r) => r.id).toList();
      expect(ids, [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
        'test-variant',
      ]);
    });

    test('upsert updates in place and keeps position', () {
      store.ensureSeeded(seedRecipes);
      final renamed = store
          .byId('sandwich-loaf')!
          .copyWith(name: 'Toast loaf', updatedAt: DateTime(2026, 4, 1));
      store.upsert(renamed);
      final all = store.all();
      expect(all.length, 3);
      expect(all[0].id, 'butter-cookies');
      expect(store.byId('sandwich-loaf')!.name, 'Toast loaf');
      expect(store.byId('sandwich-loaf')!.updatedAt, DateTime(2026, 4, 1));
    });

    test('delete removes the row', () {
      store.ensureSeeded(seedRecipes);
      store.delete('egg-free-cookies');
      expect(store.byId('egg-free-cookies'), isNull);
      expect(store.all().length, 2);
    });

    test('delete of an unknown id is a no-op', () {
      store.ensureSeeded(seedRecipes);
      store.delete('nope');
      expect(store.all().length, 3);
    });

    test('roundtrips a variant with lineage and its own rounding', () {
      store.ensureSeeded(seedRecipes);
      store.upsert(_variant());
      final restored = store.byId('test-variant')!;
      expect(restored.parentId, 'butter-cookies');
      expect(restored.createdAt, DateTime(2026, 3, 1));
      final eggLine =
          restored.lines.firstWhere((l) => l.ingredient.id == 'egg');
      expect(eggLine.ingredient.roundingStep, 0.5);
    });
  });
}
