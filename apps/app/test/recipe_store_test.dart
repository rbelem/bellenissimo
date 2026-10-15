import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';


Recipe _variant() => butterCookies.copyWith(
      id: 'test-variant',
      parentId: 'butter-cookies',
      name: 'Test variant',
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 2),
    );

void main() {

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
      expect(restored.items, hasLength(4));
      final items = restored.items;
      expect((items[0] as RecipeLine).ingredient.id, 'flour');
      expect((items[0] as RecipeLine).quantity.amount, 250);
      expect((items[0] as RecipeLine).quantity.unit, Unit.g);
      expect((items[3] as RecipeLine).ingredient.id, 'applesauce');
    });

    test('roundtrips a mass-only yield and undated recipe', () {
      final restored = RecipeCodec.decodeDoc(
        RecipeCodec.encodeDoc(sandwichLoaf),
      );
      expect(restored.yield.count, isNull);
      expect(restored.yield.totalGrams, 900);
      expect(restored.createdAt, DateTime(2026, 1, 16, 8));
      expect((restored.items[1] as RecipeLine).ingredient.gramsPerMl, 1.0);
    });

    test('keeps conversion data on ingredients', () {
      final restored = RecipeCodec.decodeDoc(
        RecipeCodec.encodeDoc(butterCookies),
      );
      final eggLine = restored.items.whereType<RecipeLine>().firstWhere(
        (l) => l.ingredient.id == 'egg',
      );
      expect(eggLine.ingredient.gramsPerPiece, 50);
      expect(eggLine.ingredient.roundingStep, 0.5);
      expect(eggLine.quantity.unit, Unit.piece);
    });

    test('roundtrips a recipe without id or lineage', () {
      const adHoc = Recipe(
        name: 'ad hoc',
        yield: YieldSpec(count: 1),
        items: [],
      );
      final restored = RecipeCodec.decodeDoc(RecipeCodec.encodeDoc(adHoc));
      expect(restored.id, isNull);
      expect(restored.parentId, isNull);
      expect(restored.items, isEmpty);
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
      expect(loaf.items, hasLength(3));
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
      final eggLine = restored.items.whereType<RecipeLine>().firstWhere(
        (l) => l.ingredient.id == 'egg',
      );
      expect(eggLine.ingredient.roundingStep, 0.5);
    });

    test('uniqueId appends a suffix on collision', () {
      store.ensureSeeded(seedRecipes);
      expect(store.uniqueId('Butter Cookies'), 'butter-cookies-2');
      expect(store.uniqueId('Sandwich loaf'), 'sandwich-loaf-2');
      expect(store.uniqueId('Pancakes'), 'pancakes');
    });
  });

  group('compound propagation', () {
    List<Object?> idsOf(RecipeStore store) =>
        [for (final recipe in store.all()) recipe.id];

    Recipe batter({String name = 'Batter', double grams = 500}) => Recipe(
      id: 'batter',
      name: name,
      yield: const YieldSpec(count: 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 2),
      items: [
        RecipeLine(
          const Ingredient('flour', gramsPerMl: 0.6),
          Quantity(grams, Unit.g),
        ),
      ],
    );

    Recipe cake() => Recipe.compound(
      id: 'cake',
      name: 'Cake',
      yield: const YieldSpec(count: 1),
      createdAt: DateTime(2026, 2, 1),
      updatedAt: DateTime(2026, 2, 2),
      tree: RecipeTree(
        name: 'assembled cake',
        components: [ComponentRef(batter(), factor: 2)],
      ),
    );

    void seedWith(RecipeStore store) {
      store.upsert(batter());
      store.upsert(cake());
    }

    test('editing batter updates every compound holding it', () {
      final store = RecipeStore.inMemory();
      seedWith(store);

      store.upsert(batter(name: 'Whole-wheat batter', grams: 600));

      final ref = store.byId('cake')!.items.single as ComponentRef;
      expect(ref.recipe.name, 'Whole-wheat batter');
      expect(
        (ref.recipe.items.single as RecipeLine).quantity.amount,
        600,
      );
      expect(ref.factor, 2);
    });

    test('propagation never bumps the holder timestamps', () {
      final store = RecipeStore.inMemory();
      seedWith(store);

      store.upsert(batter(name: 'Whole-wheat batter'));

      final cake = store.byId('cake')!;
      expect(cake.createdAt, DateTime(2026, 2, 1));
      expect(cake.updatedAt, DateTime(2026, 2, 2));
    });

    test('recipes that hold no ref stay untouched', () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      seedWith(store);
      final before = RecipeCodec.encode(store.byId('butter-cookies')!);

      store.upsert(batter(name: 'Whole-wheat batter'));

      expect(RecipeCodec.encode(store.byId('butter-cookies')!), before);
    });

    test('upserting the compound itself does not double-write', () {
      final store = RecipeStore.inMemory();
      seedWith(store);

      store.upsert(cake().copyWith(name: 'Cake v2'));

      expect(idsOf(store), ['batter', 'cake']);
      expect(store.byId('cake')!.name, 'Cake v2');
    });

    test('a null-id recipe never matches a ref snapshot', () {      final store = RecipeStore.inMemory();
      final dash = Recipe(
        name: 'Dash of salt',
        yield: const YieldSpec(count: 1),
        items: [
          RecipeLine(const Ingredient('salt'), const Quantity(5, Unit.g)),
        ],
      );
      final cake = Recipe.compound(
        id: 'cake',
        name: 'Cake',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(
          name: 'assembled cake',
          components: [
            ComponentRef(batter(), factor: 2),
            ComponentRef(dash, factor: 1),
          ],
        ),
      );
      store.upsert(batter());
      store.upsert(cake);

      store.upsert(dash.copyWith(name: 'Fancy salt'));

      expect(idsOf(store), ['batter', 'cake', null]);
      final items = store.byId('cake')!.items;
      expect((items[1] as ComponentRef).recipe.name, 'Dash of salt');
    });

    test('propagation walks a store holding a legacy tree doc', () {
      Map<String, Object?> legacyBatter({String name = 'Batter'}) => {
        'id': 'batter',
        'name': name,
        'parentId': null,
        'yield': {'count': 1, 'totalGrams': null},
        'createdAt': null,
        'updatedAt': null,
        'steps': const <String>[],
        'lines': [
          {
            'ingredient': 'flour',
            'gramsPerMl': 0.6,
            'gramsPerPiece': null,
            'roundingStep': null,
            'scalingExponent': null,
            'value': 500,
            'unit': 'g',
          },
        ],
        'blends': const [],
      };
      final legacyCake = {
        'id': 'cake',
        'name': 'Cake',
        'parentId': null,
        'yield': {'count': 1, 'totalGrams': null},
        'createdAt': null,
        'updatedAt': null,
        'steps': const <String>[],
        'lines': const [],
        'blends': const [],
        'tree': {
          'name': 'Cake',
          'components': [
            {'ref': legacyBatter(), 'factor': 2},
          ],
        },
      };
      final dir = Directory.systemTemp.createTempSync('bellenissimos-legacy-');
      addTearDown(() => dir.deleteSync(recursive: true));
      File('${dir.path}/recipes.json').writeAsStringSync(
        jsonEncode({
          'recipes': [legacyBatter(), legacyCake],
        }),
      );
      final store = RecipeStore.open('${dir.path}/recipes.json');

      store.upsert(
        Recipe(
          id: 'batter',
          name: 'Whole-wheat batter',
          yield: const YieldSpec(count: 1),
          items: [
            RecipeLine(
              const Ingredient('flour', gramsPerMl: 0.6),
              const Quantity(600, Unit.g),
            ),
          ],
        ),
      );

      final ref = store.byId('cake')!.items.single as ComponentRef;
      expect(ref.recipe.name, 'Whole-wheat batter');
      expect(ref.factor, 2);
    });
  });

  group('file-backed RecipeStore', () {
    test('persists across opens and creates parent directories', () {
      final dir = Directory.systemTemp.createTempSync('bellenissimos-open-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/nested/recipes.json';

      RecipeStore.open(path).ensureSeeded(seedRecipes);
      expect(File(path).existsSync(), isTrue);

      final reopened = RecipeStore.open(path);
      expect(reopened.all().length, 3);
      expect(reopened.byId('sandwich-loaf')!.yield.totalGrams, 900);
    });

    test('a delete through one open is visible through the next', () {
      final dir = Directory.systemTemp.createTempSync('bellenissimos-open-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/recipes.json';
      RecipeStore.open(path).ensureSeeded(seedRecipes);

      RecipeStore.open(path).delete('egg-free-cookies');

      expect(RecipeStore.open(path).all().map((r) => r.id),
          ['butter-cookies', 'sandwich-loaf']);
    });
  });
}
