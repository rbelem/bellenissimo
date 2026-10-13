import 'package:bellenissimos_core/core.dart';
import 'package:sqlite3/sqlite3.dart';

import 'recipe_codec.dart';

/// SQLite-backed recipe storage. The whole recipe travels as one JSON
/// document per row; columns exist only for identity, ordering, and
/// lineage lookups.
class RecipeStore {
  RecipeStore._(this._db);

  /// In-memory store for tests and as a fallback when no database file
  /// can be opened.
  factory RecipeStore.inMemory() {
    final store = RecipeStore._(sqlite3.openInMemory());
    store._ensureSchema();
    return store;
  }

  factory RecipeStore.open(String path) {
    final store = RecipeStore._(sqlite3.open(path));
    store._ensureSchema();
    return store;
  }

  final Database _db;

  void _ensureSchema() {
    _db.execute('''
      CREATE TABLE IF NOT EXISTS recipes (
        id TEXT PRIMARY KEY,
        parent_id TEXT,
        position INTEGER NOT NULL,
        doc TEXT NOT NULL
      )
    ''');
  }

  /// Inserts every seed recipe missing from the store. Existing rows —
  /// by id — are never touched, so user edits survive upgrades.
  void ensureSeeded(List<Recipe> seeds) {
    final known = _db.select('SELECT id FROM recipes').map((r) => r['id']);
    final knownIds = known.toSet();
    var position = _nextPosition();
    for (final seed in seeds) {
      if (knownIds.contains(seed.id)) continue;
      _insert(seed, position);
      position++;
    }
  }

  List<Recipe> all() => [
    for (final row in _db.select(
      'SELECT doc FROM recipes ORDER BY position',
    ))
      RecipeCodec.decodeDoc(row['doc']! as String),
  ];

  Recipe? byId(String id) {
    final rows = _db.select(
      'SELECT doc FROM recipes WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    return RecipeCodec.decodeDoc(rows.first['doc']! as String);
  }

  void upsert(Recipe recipe) {
    final existing = _db.select(
      'SELECT position FROM recipes WHERE id = ?',
      [recipe.id],
    );
    if (existing.isEmpty) {
      _insert(recipe, _nextPosition());
    } else {
      _db.execute(
        'UPDATE recipes SET parent_id = ?, doc = ? WHERE id = ?',
        [recipe.parentId, RecipeCodec.encodeDoc(recipe), recipe.id],
      );
    }
  }

  void delete(String id) {
    _db.execute('DELETE FROM recipes WHERE id = ?', [id]);
  }

  void _insert(Recipe recipe, int position) {
    _db.execute(
      'INSERT INTO recipes (id, parent_id, position, doc) VALUES (?, ?, ?, ?)',
      [
        recipe.id,
        recipe.parentId,
        position,
        RecipeCodec.encodeDoc(recipe),
      ],
    );
  }

  int _nextPosition() {
    final rows = _db.select('SELECT COALESCE(MAX(position), -1) + 1 AS next FROM recipes');
    return rows.first['next']! as int;
  }
}
