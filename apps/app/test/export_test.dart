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

Recipe _variant() => butterCookies.copyWith(
  id: 'test-variant',
  parentId: 'butter-cookies',
  name: 'Test variant',
  createdAt: DateTime(2026, 3, 1),
  updatedAt: DateTime(2026, 3, 2),
);

Recipe _renamedButter() => butterCookies.copyWith(name: 'Butter cookies v2');

BlendRecord _honeyMix() => BlendRecord(
  blend: SweetenerBlend(
    id: 'honey-mix',
    name: 'Honey mix',
    grams: {const Ingredient('honey'): 60, const Ingredient('sugar'): 140},
    sweetnessPerGram: {
      const Ingredient('honey'): 1.1,
      const Ingredient('sugar'): 1.0,
    },
  ),
);

List<Map<String, Object?>> _docs(RecipeStore store) => [
  for (final recipe in store.all()) RecipeCodec.encode(recipe),
];

List<String> _ids(RecipeStore store) => [
  for (final recipe in store.all()) recipe.id!,
];

String _rawBox({Object? version = boxVersion, Object? recipes}) =>
    jsonEncode({'version': version, 'recipes': recipes});

Recipe _batter() => Recipe(
  id: 'batter',
  name: 'Batter',
  yield: const YieldSpec(count: 1),
  items: [
    RecipeLine(const Ingredient('flour'), const Quantity(500, Unit.g)),
  ],
);

Recipe _dashOfSalt() => Recipe(
  name: 'Dash of salt',
  yield: const YieldSpec(count: 1),
  items: [RecipeLine(const Ingredient('salt'), const Quantity(5, Unit.g))],
);

Recipe _tart() => Recipe.compound(
  id: 'tart',
  name: 'Tart',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(
    name: 'tart shell',
    components: [ComponentRef(_dashOfSalt(), factor: 1)],
  ),
);

Recipe _compound() => Recipe.compound(
  id: 'cake',
  name: 'Cake',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(
    name: 'assembled cake',
    components: [
      ComponentRef(_batter(), factor: 2),
      ComponentRef(_tart(), factor: 1),
      RecipeLine(const Ingredient('salt'), const Quantity(5, Unit.g)),
    ],
  ),
);

void main() {
  group('exportBox', () {
    test('marks the document with the version and every recipe', () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      store.upsert(_variant());

      final decoded =
          jsonDecode(store.exportBox(const [])) as Map<String, Object?>;

      expect(decoded['version'], boxVersion);
      expect(decoded['recipes'], hasLength(4));
    });

    test('serializes recipes as codec docs and carries the blend library', () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final blends = BlendStore.inMemory(store)..upsertAll([_honeyMix()]);

      final decoded =
          jsonDecode(store.exportBox(blends.all())) as Map<String, Object?>;

      expect(
        (decoded['recipes']! as List<Object?>).first,
        RecipeCodec.encode(butterCookies),
      );
      expect(decoded['blends'], hasLength(1));
    });
  });

  group('importBox replace', () {
    test('restores the exported box byte-equivalent through the codec', () {
      final source = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final sourceBlends = BlendStore.inMemory(source)
        ..upsertAll([_honeyMix()]);
      source.upsert(_variant());
      final target = RecipeStore.inMemory();
      final targetBlends = BlendStore.inMemory(target);

      final result = target.importBox(
        source.exportBox(sourceBlends.all()),
        mode: BoxImportMode.replace,
        blends: targetBlends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 4);
      expect(result.blends, 1);
      expect(result.issues, isEmpty);
      expect(_docs(target), _docs(source));
      expect(targetBlends.byId('honey-mix')!.blend.totalGrams, 200);
      expect(_ids(target), [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
        'test-variant',
      ]);
    });

    test('drops recipes absent from the payload', () {
      final payloadSource = RecipeStore.inMemory();
      payloadSource.upsert(_renamedButter());
      payloadSource.upsert(_variant());
      final target = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final targetBlends = BlendStore.inMemory(target);

      target.importBox(
        payloadSource.exportBox(const []),
        mode: BoxImportMode.replace,
        blends: targetBlends,
      );

      expect(_ids(target), ['butter-cookies', 'test-variant']);
      expect(target.byId('butter-cookies')!.name, 'Butter cookies v2');
    });

    test('survives a reopen of a file-backed store', () {
      final dir = Directory.systemTemp.createTempSync('bellenissimos-box-');
      addTearDown(() => dir.deleteSync(recursive: true));
      final source = RecipeStore.open('${dir.path}/a/recipes.json')
        ..ensureSeeded(seedRecipes);
      source.upsert(_variant());
      final targetPath = '${dir.path}/nested/b/recipes.json';

      RecipeStore.open(targetPath).importBox(
        source.exportBox(const []),
        mode: BoxImportMode.replace,
        blends: BlendStore.open(
          '${dir.path}/nested/b/blends.json',
          recipes: RecipeStore.open(targetPath),
        ),
      );

      final reopened = RecipeStore.open(targetPath);
      expect(_ids(reopened), _ids(source));
      expect(_docs(reopened), _docs(source));
    });
  });

  group('importBox merge', () {
    test('incoming id wins, payload-absent ids survive', () {
      final payloadSource = RecipeStore.inMemory();
      payloadSource.upsert(_renamedButter());
      payloadSource.upsert(_variant());
      final target = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final targetBlends = BlendStore.inMemory(target);

      final result = target.importBox(
        payloadSource.exportBox(const []),
        mode: BoxImportMode.merge,
        blends: targetBlends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 2);
      expect(result.issues, isEmpty);
      expect(_ids(target), [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
        'test-variant',
      ]);
      expect(target.byId('butter-cookies')!.name, 'Butter cookies v2');
      expect(target.byId('egg-free-cookies')!.name, 'Egg-free butter cookies');
      expect(target.byId('test-variant')!.parentId, 'butter-cookies');
    });

    test('skips an unreadable entry and reports the issue', () {
      final target = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final targetBlends = BlendStore.inMemory(target);
      final payload = _rawBox(
        recipes: [
          RecipeCodec.encode(_variant()),
          {'name': 'junk'},
        ],
      );

      final result = target.importBox(
        payload,
        mode: BoxImportMode.merge,
        blends: targetBlends,
      );

      expect(result.imported, 1);
      expect(result.issues, hasLength(1));
      expect(result.ok, isFalse);
      expect(_ids(target), [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
        'test-variant',
      ]);
    });
    test('skips a blend entry without an id', () {
      final target = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final targetBlends = BlendStore.inMemory(target);
      final payload = jsonEncode({
        'version': boxVersion,
        'blends': [BlendCodec.encode(_honeyMix().blend)..remove('id')],
        'recipes': [RecipeCodec.encode(_variant())],
      });

      final result = target.importBox(
        payload,
        mode: BoxImportMode.merge,
        blends: targetBlends,
      );

      expect(result.imported, 1);
      expect(result.blends, 0);
      expect(
        result.issues.single.toString(),
        'Blend entry without an id skipped',
      );
      expect(targetBlends.all(), isEmpty);
    });
  });

  group('importBox rejects bad payloads without touching the store', () {
    late RecipeStore store;
    late BlendStore blends;

    setUp(() {
      store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      blends = BlendStore.inMemory(store)..upsertAll([_honeyMix()]);
    });

    test('malformed JSON', () {
      final result = store.importBox(
        '{oops',
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.map((i) => i.toString()), ['Malformed JSON']);
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });

    test('document without a version marker', () {
      final result = store.importBox(
        '{}',
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Missing box version marker');
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });

    test('empty payload', () {
      final result = store.importBox(
        _rawBox(recipes: []),
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Box contains no recipes');
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });

    test('missing recipes list', () {
      final result = store.importBox(
        '{"version": 1}',
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Missing recipes list');
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });

    test('newer version marker', () {
      final result = store.importBox(
        _rawBox(version: 99, recipes: [RecipeCodec.encode(_variant())]),
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Unsupported box version: 99');
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });

    test('not a document', () {
      for (final source in ['[1, 2]', '"nope"', '42']) {
        final result = store.importBox(
          source,
          mode: BoxImportMode.merge,
          blends: blends,
        );

        expect(result.imported, 0);
        expect(result.issues.single.toString(), 'Not a box document');
      }
      expect(store.all(), hasLength(3));
      expect(blends.all(), hasLength(1));
    });
  });

  group('version matrix', () {
    late RecipeStore store;
    late BlendStore blends;

    setUp(() {
      store = RecipeStore.inMemory();
      blends = BlendStore.inMemory(store);
    });

    test('a version 1 doc loads', () {
      final payload =
          '{"version": 1, "recipes": [${jsonEncode(RecipeCodec.encode(_variant()))}, ${jsonEncode(RecipeCodec.encode(_dashOfSalt()))}]}';

      final result = store.importBox(
        payload,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 2);
      expect(store.all().map((r) => r.name), [
        'Test variant',
        'Dash of salt',
      ]);
    });

    test('a version 2 doc loads with no trees', () {
      final payload = _rawBox(
        version: 2,
        recipes: [RecipeCodec.encode(_variant()), RecipeCodec.encode(_batter())],
      );

      final result = store.importBox(
        payload,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 2);
      expect(store.byId('test-variant')!.isCompound, isFalse);
    });

    test('a v4 box with unified items roundtrips through export and import', () {
      final source = RecipeStore.inMemory();
      source.upsert(_batter());
      source.upsert(_compound());

      final result = store.importBox(
        source.exportBox(const []),
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 2);
      final restored = store.byId('cake')!;
      expect(restored.isCompound, isTrue);
      final items = restored.items;
      final batter = items[0] as ComponentRef;
      expect(batter.recipe.id, 'batter');
      expect(batter.factor, 2);
      expect(
        (batter.recipe.items.single as RecipeLine).quantity.amount,
        500,
      );
      final tart = items[1] as ComponentRef;
      expect(tart.recipe.isCompound, isTrue);
      final inner = tart.recipe.items.single as ComponentRef;
      expect(inner.recipe.id, isNull);
      expect(
        (inner.recipe.items.single as RecipeLine).ingredient.id,
        'salt',
      );
      final leaf = items[2] as RecipeLine;
      expect(leaf.ingredient.id, 'salt');
      expect(leaf.quantity.amount, 5);
    });

    test('a v4 payload merges unified recipes beside existing recipes', () {
      final payloadSource = RecipeStore.inMemory();
      payloadSource.upsert(_batter());
      payloadSource.upsert(_compound());
      store.ensureSeeded(seedRecipes);

      final result = store.importBox(
        payloadSource.exportBox(const []),
        mode: BoxImportMode.merge,
        blends: blends,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 2);
      expect(_ids(store), [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
        'batter',
        'cake',
      ]);
      expect(store.byId('cake')!.isCompound, isTrue);
    });

    test('a future version is refused with the existing issue text', () {
      final result = store.importBox(
        _rawBox(
          version: boxVersion + 1,
          recipes: [RecipeCodec.encode(_variant())],
        ),
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(
        result.issues.single.toString(),
        'Unsupported box version: ${boxVersion + 1}',
      );
      expect(store.all(), isEmpty);
    });
  });

  group('legacy corruption and id collisions', () {
    Map<String, Object?> legacyDoc({
      List<Object?> lines = const [],
      List<Object?> blends = const [],
      Map<String, Object?>? tree,
    }) => {
      'id': 'cake',
      'name': 'Cake',
      'parentId': null,
      'yield': {'count': 1, 'totalGrams': null},
      'createdAt': null,
      'updatedAt': null,
      'steps': const <String>[],
      'lines': lines,
      'blends': blends,
      'tree': tree,
    };

    Map<String, Object?> legacyTree(List<Object?> components) => {
      'name': 'assembled cake',
      'components': components,
    };

    test('a legacy doc with both tree and lines becomes an issue, store untouched',
        () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      final blends = BlendStore.inMemory(store);
      final lineDoc = {
        'ingredient': 'flour',
        'gramsPerMl': 0.6,
        'gramsPerPiece': null,
        'roundingStep': null,
        'scalingExponent': null,
        'value': 500,
        'unit': 'g',
      };
      final payload = _rawBox(
        recipes: [
          legacyDoc(lines: [lineDoc], tree: legacyTree(const [])),
        ],
      );

      final result = store.importBox(
        payload,
        mode: BoxImportMode.replace,
        blends: blends,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(),
          'Unreadable recipe entry "Cake" skipped');
      expect(_ids(store), [
        'butter-cookies',
        'egg-free-cookies',
        'sandwich-loaf',
      ]);
      expect(blends.all(), isEmpty);
    });

    test('a legacy doc with both tree and blends becomes an issue', () {
      final blend = SweetenerBlend(
        name: 'mix',
        grams: {const Ingredient('honey'): 60},
        sweetnessPerGram: {const Ingredient('honey'): 1.1},
      );
      final doc = legacyDoc(
        blends: [BlendCodec.encodeLine(BlendLine(blend, 100))],
        tree: legacyTree(const []),
      );

      final (recipes, _, issues) = parseBox(_rawBox(recipes: [doc]));

      expect(recipes, isEmpty);
      expect(issues.single.toString(),
          'Unreadable recipe entry "Cake" skipped');
    });

    test('a duplicate top-level id is skipped, first wins', () {
      final payload = _rawBox(recipes: [
        RecipeCodec.encode(_variant()),
        RecipeCodec.encode(_variant().copyWith(name: 'Second variant')),
      ]);

      final (recipes, _, issues) = parseBox(payload);

      expect(recipes, hasLength(1));
      expect(recipes.single.name, 'Test variant');
      expect(
        issues.single.toString(),
        'Duplicate recipe id "test-variant" skipped',
      );
    });

    test('a ref snapshot colliding with a top-level id skips the later entry',
        () {
      final holder = Recipe.compound(
        id: 'cake',
        name: 'Cake',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(
          name: 'assembled cake',
          components: [ComponentRef(_variant(), factor: 2)],
        ),
      );
      final payload = _rawBox(recipes: [
        RecipeCodec.encode(holder),
        RecipeCodec.encode(_variant().copyWith(name: 'Renamed variant')),
      ]);

      final (recipes, _, issues) = parseBox(payload);

      expect(recipes.map((r) => r.id), ['cake']);
      expect(
        issues.single.toString(),
        'Duplicate recipe id "test-variant" skipped',
      );
    });

    test('a top-level id colliding with an earlier ref snapshot skips it', () {
      final payload = _rawBox(recipes: [
        RecipeCodec.encode(_compound()),
        RecipeCodec.encode(_batter().copyWith(name: 'Whole-wheat batter')),
      ]);

      final (recipes, _, issues) = parseBox(payload);

      expect(recipes.map((r) => r.id), ['cake']);
      expect(
        issues.single.toString(),
        'Duplicate recipe id "batter" skipped',
      );
    });

    test('a part beside its own unchanged snapshot imports both', () {
      final payload = _rawBox(recipes: [
        RecipeCodec.encode(_compound()),
        RecipeCodec.encode(_batter()),
      ]);

      final (recipes, _, issues) = parseBox(payload);

      expect(recipes.map((r) => r.id), ['cake', 'batter']);
      expect(issues, isEmpty);
    });
  });
}
