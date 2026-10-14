import 'dart:convert';
import 'dart:io';

import 'package:bellenissimos_core/core.dart';

import 'recipe_store.dart';
import 'blend_codec.dart';

/// JSON-file-backed blend library: same one-document atomic-write
/// pattern as [RecipeStore].
///
/// Editing a blend must reach every recipe that attached it, so
/// [upsertBlend] walks the recipe store through
/// [RecipeBook.replacingBlend] and upserts only the recipes that
/// actually changed — propagation lives here, never in UI code.
/// Deleting a blend touches only the library: recipes keep their
/// attached copy, so no attachment can dangle.
class BlendStore {
  BlendStore._(this._file, this._recipes);

  /// Isolated store for tests: a fresh file in a throwaway directory.
  factory BlendStore.inMemory(RecipeStore recipes) {
    final dir = Directory.systemTemp.createTempSync('bellenissimos-blends-');
    return BlendStore._(File('${dir.path}/blends.json'), recipes);
  }

  /// Store backed by [path] (a JSON file). Parent directories are
  /// created on demand.
  factory BlendStore.open(String path, {required RecipeStore recipes}) {
    final file = File(path);
    file.parent.createSync(recursive: true);
    return BlendStore._(file, recipes);
  }

  final File _file;
  final RecipeStore _recipes;
  List<Map<String, Object?>> _docs = [];

  void _load() {
    if (!_file.existsSync()) {
      _docs = [];
      return;
    }
    final decoded = jsonDecode(_file.readAsStringSync());
    _docs = [
      for (final doc
          in (decoded as Map<String, Object?>)['blends']! as List<Object?>)
        doc! as Map<String, Object?>,
    ];
  }

  void _flush() {
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({'blends': _docs}),
    );
    tmp.renameSync(_file.path);
  }

  List<BlendRecord> all() {
    _load();
    return [for (final doc in _docs) BlendCodec.decode(doc)];
  }

  BlendRecord? byId(String id) {
    _load();
    for (final doc in _docs) {
      if (doc['id'] == id) return BlendCodec.decode(doc);
    }
    return null;
  }

  /// Inserts or replaces [record] by blend id, then rewrites every
  /// recipe whose attached copy of that blend changed.
  void upsertBlend(BlendRecord record) {
    final id = record.blend.id;
    if (id == null) {
      throw ArgumentError('A library blend needs an id');
    }
    _load();
    final encoded = BlendCodec.encode(
      record.blend,
      createdAt: record.createdAt,
      updatedAt: record.updatedAt,
    );
    final index = _docs.indexWhere((doc) => doc['id'] == id);
    if (index == -1) {
      _docs.add(encoded);
    } else {
      _docs[index] = encoded;
    }
    _flush();
    _propagate(id, record.blend);
  }

  void _propagate(String blendId, Blend blend) {
    final before = _recipes.all();
    final after = RecipeBook(before).replacingBlend(blendId, blend);
    for (var i = 0; i < before.length; i++) {
      if (!identical(before[i], after.recipes[i])) {
        _recipes.upsert(after.recipes[i]);
      }
    }
  }

  /// Removes the library row. Attached recipes are untouched on
  /// purpose: their [BlendLine] holds the blend value.
  void delete(String id) {
    _load();
    _docs.removeWhere((doc) => doc['id'] == id);
    _flush();
  }

  /// Box-import replace semantics: the library becomes [records].
  void replaceAll(List<BlendRecord> records) {
    _docs = [
      for (final record in records)
        BlendCodec.encode(
          record.blend,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
    ];
    _flush();
  }

  /// Box-import merge semantics: every incoming record upserts by id.
  void upsertAll(List<BlendRecord> records) {
    _load();
    for (final record in records) {
      final encoded = BlendCodec.encode(
        record.blend,
        createdAt: record.createdAt,
        updatedAt: record.updatedAt,
      );
      final index = _docs.indexWhere((doc) => doc['id'] == record.blend.id);
      if (index == -1) {
        _docs.add(encoded);
      } else {
        _docs[index] = encoded;
      }
    }
    _flush();
  }

  /// A unique, slug-derived id for [name] within this store.
  String uniqueId(String name) {
    var slug = name
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (slug.isEmpty) slug = 'blend';
    var candidate = slug;
    var n = 2;
    while (byId(candidate) != null) {
      candidate = '$slug-${n++}';
    }
    return candidate;
  }
}
