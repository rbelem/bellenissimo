import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_app/export/box_io.dart';
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

List<Map<String, Object?>> _docs(RecipeStore store) => [
  for (final recipe in store.all()) RecipeCodec.encode(recipe),
];

List<String> _ids(RecipeStore store) => [
  for (final recipe in store.all()) recipe.id!,
];

String _rawBox({Object? version = boxVersion, Object? recipes}) =>
    jsonEncode({'version': version, 'recipes': recipes});

void main() {
  group('exportBox', () {
    test('marks the document with the version and every recipe', () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      store.upsert(_variant());

      final decoded = jsonDecode(store.exportBox()) as Map<String, Object?>;

      expect(decoded['version'], 1);
      expect(decoded['recipes'], hasLength(4));
    });

    test('serializes recipes as codec docs', () {
      final store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);

      final decoded = jsonDecode(store.exportBox()) as Map<String, Object?>;

      expect(
        (decoded['recipes']! as List<Object?>).first,
        RecipeCodec.encode(butterCookies),
      );
    });
  });

  group('importBox replace', () {
    test('restores the exported box byte-equivalent through the codec', () {
      final source = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
      source.upsert(_variant());
      final target = RecipeStore.inMemory();

      final result = target.importBox(
        source.exportBox(),
        mode: BoxImportMode.replace,
      );

      expect(result.ok, isTrue);
      expect(result.imported, 4);
      expect(result.issues, isEmpty);
      expect(_docs(target), _docs(source));
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

      target.importBox(payloadSource.exportBox(), mode: BoxImportMode.replace);

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

      RecipeStore.open(targetPath)
          .importBox(source.exportBox(), mode: BoxImportMode.replace);

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

      final result = target.importBox(
        payloadSource.exportBox(),
        mode: BoxImportMode.merge,
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
      final payload = _rawBox(
        recipes: [
          RecipeCodec.encode(_variant()),
          {'name': 'junk'},
        ],
      );

      final result = target.importBox(payload, mode: BoxImportMode.merge);

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
  });

  group('importBox rejects bad payloads without touching the store', () {
    late RecipeStore store;

    setUp(() => store = RecipeStore.inMemory()..ensureSeeded(seedRecipes));

    test('malformed JSON', () {
      final result = store.importBox('{oops', mode: BoxImportMode.replace);

      expect(result.imported, 0);
      expect(result.issues.map((i) => i.toString()), ['Malformed JSON']);
      expect(store.all(), hasLength(3));
    });

    test('document without a version marker', () {
      final result = store.importBox('{}', mode: BoxImportMode.replace);

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Missing box version marker');
      expect(store.all(), hasLength(3));
    });

    test('empty payload', () {
      final result = store.importBox(
        _rawBox(recipes: []),
        mode: BoxImportMode.replace,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Box contains no recipes');
      expect(store.all(), hasLength(3));
    });

    test('missing recipes list', () {
      final result = store.importBox(
        '{"version": 1}',
        mode: BoxImportMode.replace,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Missing recipes list');
      expect(store.all(), hasLength(3));
    });

    test('newer version marker', () {
      final result = store.importBox(
        _rawBox(version: 2, recipes: [RecipeCodec.encode(_variant())]),
        mode: BoxImportMode.replace,
      );

      expect(result.imported, 0);
      expect(result.issues.single.toString(), 'Unsupported box version: 2');
      expect(store.all(), hasLength(3));
    });

    test('not a document', () {
      for (final source in ['[1, 2]', '"nope"', '42']) {
        final result = store.importBox(source, mode: BoxImportMode.merge);

        expect(result.imported, 0);
        expect(result.issues.single.toString(), 'Not a box document');
      }
      expect(store.all(), hasLength(3));
    });
  });
}
