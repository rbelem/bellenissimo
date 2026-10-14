import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_core/core.dart';

import 'recipe_codec.dart';

/// JSON-file-backed recipe storage: one document, one list, written
/// atomically. Same lifecycle as a database would have — open, seed,
/// upsert, delete — without a native dependency.
class RecipeStore {
  RecipeStore._(this._file);

  /// Isolated store for tests: a fresh file in a throwaway directory.
  factory RecipeStore.inMemory() {
    final dir = Directory.systemTemp.createTempSync('bellenissimos-');
    return RecipeStore._(File('${dir.path}/recipes.json'));
  }

  /// Store backed by [path] (a JSON file). Parent directories are
  /// created on demand.
  factory RecipeStore.open(String path) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    return RecipeStore._(file);
  }

  final File _file;
  List<Map<String, Object?>> _docs = [];

  void _load() {
    if (!_file.existsSync()) {
      _docs = [];
      return;
    }
    final decoded = jsonDecode(_file.readAsStringSync());
    _docs = [
      for (final doc in (decoded as Map<String, Object?>)['recipes']!
          as List<Object?>)
        doc! as Map<String, Object?>,
    ];
  }

  void _flush() {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
      'recipes': _docs,
    }));
    tmp.renameSync(_file.path);
  }

  /// Inserts every seed recipe missing from the store. Existing rows —
  /// by id — are never touched, so user edits survive upgrades.
  void ensureSeeded(List<Recipe> seeds) {
    _load();
    final known = _docs.map((doc) => doc['id']).toSet();
    for (final seed in seeds) {
      if (known.contains(seed.id)) continue;
      _docs.add(RecipeCodec.encode(seed));
    }
    _flush();
  }

  List<Recipe> all() {
    _load();
    return [for (final doc in _docs) RecipeCodec.decode(doc)];
  }

  Recipe? byId(String id) {
    _load();
    for (final doc in _docs) {
      if (doc['id'] == id) return RecipeCodec.decode(doc);
    }
    return null;
  }

  void upsert(Recipe recipe) {
    _load();
    final encoded = RecipeCodec.encode(recipe);
    final index = _docs.indexWhere((doc) => doc['id'] == recipe.id);
    if (index == -1) {
      _docs.add(encoded);
    } else {
      _docs[index] = encoded;
    }
    _flush();
  }

  void delete(String id) {
    _load();
    _docs.removeWhere((doc) => doc['id'] == id);
    _flush();
  }

  /// A unique, slug-derived id for [name] within this store.
  String uniqueId(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'recipe';
    var candidate = slug;
    var n = 2;
    while (byId(candidate) != null) {
      candidate = '$slug-${n++}';
    }
    return candidate;
  }
}
