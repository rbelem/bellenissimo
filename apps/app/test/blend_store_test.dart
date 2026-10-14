import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_app/export/box_io.dart';
import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/blend_store.dart';
import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';

BlendRecord _erythritolXylitol({String? id}) => BlendRecord(
  blend: SweetenerBlend(
    id: id,
    name: 'Erythritol xylitol',
    grams: {
      const Ingredient('erythritol'): 100,
      const Ingredient('xylitol'): 100,
    },
    sweetnessPerGram: {
      const Ingredient('erythritol'): 0.7,
      const Ingredient('xylitol'): 1.0,
    },
  ),
  createdAt: DateTime(2026, 3, 1, 9),
  updatedAt: DateTime(2026, 3, 2, 10),
);

BlendRecord _breadMix() => BlendRecord(
  blend: FlourMix(
    id: 'bread-mix',
    name: 'Bread mix',
    grams: {
      const Ingredient('flour'): 700,
      const Ingredient('whole_wheat_flour'): 300,
    },
    proteinPct: {
      const Ingredient('flour'): 10,
      const Ingredient('whole_wheat_flour'): 14,
    },
  ),
);

Recipe _recipeWith(Blend blend) => butterCookies.copyWith(
  id: 'blend-cookies',
  blends: [BlendLine(blend, 120)],
);

void main() {
  group('BlendCodec', () {
    test('roundtrips a sweetener blend with timestamps', () {
      final record = _erythritolXylitol(id: 'ery-xyl');

      final restored = BlendCodec.decode(
        BlendCodec.encode(
          record.blend,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
      );

      final blend = restored.blend as SweetenerBlend;
      expect(blend.id, 'ery-xyl');
      expect(blend.name, 'Erythritol xylitol');
      expect(blend.grams.keys.map((i) => i.id), ['erythritol', 'xylitol']);
      expect(blend.grams[const Ingredient('erythritol')], 100);
      expect(blend.sweetnessPerGram[const Ingredient('erythritol')], 0.7);
      expect(blend.sucroseEquivalentPerGram, closeTo(0.85, 1e-9));
      expect(restored.createdAt, DateTime(2026, 3, 1, 9));
      expect(restored.updatedAt, DateTime(2026, 3, 2, 10));
    });

    test('roundtrips a flour mix with conversion fields on parts', () {
      final record = _breadMix();

      final doc = BlendCodec.encode(record.blend);
      expect(doc['kind'], 'flour');
      final part =
          (doc['parts']! as List<Object?>).first! as Map<String, Object?>;
      expect(part['ingredient'], 'flour');
      expect(part['grams'], 700);
      expect(part['attribute'], 10);

      final restored = BlendCodec.decode(doc);
      final blend = restored.blend as FlourMix;
      expect(blend.proteinPct, closeTo(11.2, 1e-9));
      expect(blend.breadHydrationPct(), closeTo(61.6, 1e-9));
    });

    test('roundtrips an attached blend line by value', () {
      final record = _erythritolXylitol(id: 'ery-xyl');

      final restored = BlendCodec.decodeLine(
        BlendCodec.encodeLine(BlendLine(record.blend, 120)),
      );

      expect(restored.grams, 120);
      expect(restored.blend.id, 'ery-xyl');
      expect(restored.blend.name, 'Erythritol xylitol');
      expect(restored.blend.totalGrams, 200);
    });

    test('rejects an unknown kind', () {
      final doc = BlendCodec.encode(_erythritolXylitol().blend)
        ..['kind'] = 'spice';

      expect(() => BlendCodec.decode(doc), throwsArgumentError);
    });
  });

  group('BlendStore', () {
    late RecipeStore recipes;
    late BlendStore store;

    setUp(() {
      recipes = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      store = BlendStore.inMemory(recipes);
    });

    test('starts empty and roundtrips records', () {
      expect(store.all(), isEmpty);
      store.upsertBlend(_erythritolXylitol(id: 'ery-xyl'));
      store.upsertBlend(_breadMix());

      expect(store.all().map((r) => r.blend.name).toList(), [
        'Erythritol xylitol',
        'Bread mix',
      ]);
      expect(store.byId('ery-xyl')!.blend.name, 'Erythritol xylitol');
      expect(store.byId('ery-xyl')!.createdAt, DateTime(2026, 3, 1, 9));
      expect(store.byId('nope'), isNull);
    });

    test('upsertBlend rewrites recipes holding the blend, grams preserved', () {
      final original = _erythritolXylitol(id: 'ery-xyl');
      recipes.upsert(_recipeWith(original.blend));
      store.upsertBlend(original);

      final renamed = BlendRecord(
        blend: SweetenerBlend(
          id: 'ery-xyl',
          name: 'Ery xyl v2',
          grams: {
            const Ingredient('erythritol'): 150,
            const Ingredient('xylitol'): 50,
          },
          sweetnessPerGram: {
            const Ingredient('erythritol'): 0.7,
            const Ingredient('xylitol'): 1.0,
          },
        ),
      );
      store.upsertBlend(renamed);

      final line = recipes.byId('blend-cookies')!.blends.single;
      expect(line.grams, 120);
      expect(line.blend.name, 'Ery xyl v2');
      expect(line.blend.totalGrams, 200);
    });

    test('upsertBlend leaves recipes without the blend untouched', () {
      final before = RecipeCodec.encode(recipes.byId('sandwich-loaf')!);
      store.upsertBlend(_erythritolXylitol(id: 'ery-xyl'));

      expect(RecipeCodec.encode(recipes.byId('sandwich-loaf')!), before);
    });

    test(
      'delete removes the library row; recipes keep their attached copy',
      () {
        final record = _erythritolXylitol(id: 'ery-xyl');
        recipes.upsert(_recipeWith(record.blend));
        store.upsertBlend(record);

        store.delete('ery-xyl');

        expect(store.byId('ery-xyl'), isNull);
        expect(
          recipes.byId('blend-cookies')!.blends.single.blend.name,
          'Erythritol xylitol',
        );
      },
    );

    test('upsertBlend refuses a blend without an id', () {
      expect(
        () => store.upsertBlend(_erythritolXylitol()),
        throwsArgumentError,
      );
    });

    test('uniqueId appends a suffix on collision', () {
      final blend = _erythritolXylitol(id: 'erythritol-xylitol').blend;
      store.upsertBlend(BlendRecord(blend: blend));

      expect(store.uniqueId('Erythritol Xylitol'), 'erythritol-xylitol-2');
      expect(store.uniqueId('Bread mix'), 'bread-mix');
    });

    test('persists across opens in its own file', () {
      final dir = Directory.systemTemp.createTempSync('bellenissimos-blends-');
      addTearDown(() => dir.deleteSync(recursive: true));

      BlendStore.open(
        '${dir.path}/nested/blends.json',
        recipes: recipes,
      ).upsertBlend(_erythritolXylitol(id: 'ery-xyl'));

      final reopened = BlendStore.open(
        '${dir.path}/nested/blends.json',
        recipes: recipes,
      );
      expect(reopened.byId('ery-xyl')!.blend.name, 'Erythritol xylitol');
      expect(File('${dir.path}/nested/blends.json').existsSync(), isTrue);
    });
  });

  group('box blends', () {
    test('exportBox writes the blend library next to the recipes', () {
      final recipes = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final blends = BlendStore.inMemory(recipes)
        ..upsertBlend(_erythritolXylitol(id: 'ery-xyl'));

      final doc =
          jsonDecode(recipes.exportBox(blends.all())) as Map<String, Object?>;

      expect(doc['version'], boxVersion);
      expect(doc['recipes'], hasLength(3));
      expect(doc['blends'], hasLength(1));
    });

    test('a v1 box loads with an empty blend library', () {
      final recipes = RecipeStore.inMemory();
      final blends = BlendStore.inMemory(recipes);
      final v1 = jsonEncode({
        'version': 1,
        'recipes': [RecipeCodec.encode(seedRecipes.first)],
      });

      final result = recipes.importBox(
        v1,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 1);
      expect(result.blends, 0);
      expect(blends.all(), isEmpty);
    });

    test('a v2 box roundtrips its blends through replace and merge', () {
      final sourceRecipes = RecipeStore.inMemory()
        ..ensureSeeded([seedRecipes.first]);
      final sourceBlends = BlendStore.inMemory(sourceRecipes)
        ..upsertBlend(_erythritolXylitol(id: 'ery-xyl'));
      final targetRecipes = RecipeStore.inMemory();
      final targetBlends = BlendStore.inMemory(targetRecipes);

      final box = sourceRecipes.exportBox(sourceBlends.all());

      final replaced = targetRecipes.importBox(
        box,
        mode: BoxImportMode.replace,
        blends: targetBlends,
      );
      expect(replaced.ok, isTrue);
      expect(replaced.blends, 1);
      expect(
        (targetBlends.byId('ery-xyl')!.blend as SweetenerBlend)
            .sucroseEquivalentPerGram,
        closeTo(0.85, 1e-9),
      );

      final merged = targetRecipes.importBox(
        box,
        mode: BoxImportMode.merge,
        blends: targetBlends,
      );
      expect(merged.ok, isTrue);
      expect(targetBlends.all(), hasLength(1));
    });

    test('a junk blend entry is skipped with an issue', () {
      final recipes = RecipeStore.inMemory();
      final blends = BlendStore.inMemory(recipes);
      final good = BlendCodec.encode(_erythritolXylitol(id: 'ery-xyl').blend);
      final box = jsonEncode({
        'version': boxVersion,
        'blends': [
          good,
          {'name': 'junk'},
        ],
        'recipes': [RecipeCodec.encode(seedRecipes.first)],
      });

      final result = recipes.importBox(
        box,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 1);
      expect(result.blends, 1);
      expect(
        result.issues.single.toString(),
        'Unreadable blend entry "junk" skipped',
      );
    });

    test('a malformed blends list is reported and skipped', () {
      final recipes = RecipeStore.inMemory();
      final blends = BlendStore.inMemory(recipes);
      final box = jsonEncode({
        'version': boxVersion,
        'blends': 42,
        'recipes': [RecipeCodec.encode(seedRecipes.first)],
      });

      final result = recipes.importBox(
        box,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 1);
      expect(result.blends, 0);
      expect(result.issues.single.toString(), 'Blend list is unreadable');
    });

    test('a non-object blend entry is reported and skipped', () {
      final recipes = RecipeStore.inMemory();
      final blends = BlendStore.inMemory(recipes);
      final box = jsonEncode({
        'version': boxVersion,
        'blends': [42],
        'recipes': [RecipeCodec.encode(seedRecipes.first)],
      });

      final result = recipes.importBox(
        box,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 1);
      expect(result.blends, 0);
      expect(result.issues.single.toString(), 'Blend entry is not an object');
    });
  });
}
