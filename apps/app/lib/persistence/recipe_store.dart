import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_core/core.dart';

import '../export/box_io.dart';
import 'blend_codec.dart';
import 'blend_store.dart';
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
      for (final doc
          in (decoded as Map<String, Object?>)['recipes']! as List<Object?>)
        doc! as Map<String, Object?>,
    ];
  }

  void _flush() {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'recipes': _docs}),
    );
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

  /// Serializes the whole box to one versioned JSON document, blend
  /// library included.
  String exportBox(List<BlendRecord> blends) => encodeBox(all(), blends);

  /// Restores a box document produced by [exportBox], writing recipes
  /// into this store and blends into [blends]. In replace mode both
  /// stores are cleared first; in merge mode every incoming row upserts
  /// by id. Rejected payloads leave both stores untouched and are
  /// reported as issues; importing never throws.
  BoxImportResult importBox(
    String source, {
    required BoxImportMode mode,
    required BlendStore blends,
  }) {
    final (recipes, blendRecords, issues) = parseBox(source);
    if (recipes.isEmpty && issues.isNotEmpty) {
      return BoxImportResult(0, issues);
    }
    _load();
    final encoded = [for (final recipe in recipes) RecipeCodec.encode(recipe)];
    switch (mode) {
      case BoxImportMode.replace:
        _docs = encoded;
      case BoxImportMode.merge:
        for (final doc in encoded) {
          final index = _docs.indexWhere((d) => d['id'] == doc['id']);
          if (index == -1) {
            _docs.add(doc);
          } else {
            _docs[index] = doc;
          }
        }
    }
    _flush();
    switch (mode) {
      case BoxImportMode.replace:
        blends.replaceAll(blendRecords);
      case BoxImportMode.merge:
        blends.upsertAll(blendRecords);
    }
    return BoxImportResult(recipes.length, issues, blends: blendRecords.length);
  }
}
