import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

import '../persistence/blend_codec.dart';
import '../persistence/recipe_codec.dart';

/// Version marker of the box document format. Bump on incompatible
/// changes so old apps refuse newer files with a clear issue. Version 4
/// writes items as one ordered list; versions 1 through 3 stay readable
/// and decode into items.
const boxVersion = 4;

/// What import does with recipes already in the store.
enum BoxImportMode {
  /// Clears the store, then writes the payload.
  replace,

  /// Upserts every incoming recipe; the incoming id wins.
  merge,
}

/// One problem found while importing; importing never throws, it
/// collects these instead.
class BoxIssue {
  const BoxIssue(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The outcome of a box import: how many recipes and blends were
/// written and every issue found along the way.
class BoxImportResult {
  const BoxImportResult(this.imported, this.issues, {this.blends = 0});

  final int imported;

  final int blends;

  final List<BoxIssue> issues;

  bool get ok => issues.isEmpty;
}

/// Serializes a whole box: the blend library and every recipe as codec
/// docs, plus the version marker.
String encodeBox(List<Recipe> recipes, List<BlendRecord> blends) =>
    const JsonEncoder.withIndent('  ').convert({
      'version': boxVersion,
      'blends': [
        for (final record in blends)
          BlendCodec.encode(
            record.blend,
            createdAt: record.createdAt,
            updatedAt: record.updatedAt,
          ),
      ],
      'recipes': [for (final recipe in recipes) RecipeCodec.encode(recipe)],
    });

/// Parses a box document into the usable recipes, the blend library,
/// and every issue. Version 1 documents load with an empty blend
/// library; an empty recipe list paired with issues means the payload
/// was rejected outright and both stores must stay untouched.
(List<Recipe>, List<BlendRecord>, List<BoxIssue>) parseBox(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    return (const [], const [], [BoxIssue('Malformed JSON')]);
  }
  if (decoded is! Map) {
    return (const [], const [], [BoxIssue('Not a box document')]);
  }
  final version = decoded['version'];
  if (version is! int) {
    return (const [], const [], [BoxIssue('Missing box version marker')]);
  }
  if (version != 1 && version != 2 && version != 3 && version != boxVersion) {
    return (
      const [],
      const [],
      [BoxIssue('Unsupported box version: $version')],
    );
  }
  final rawBlends = decoded['blends'];
  final blends = <BlendRecord>[];
  final issues = <BoxIssue>[];
  if (rawBlends != null) {
    if (rawBlends is! List) {
      issues.add(const BoxIssue('Blend list is unreadable'));
    } else {
      for (final doc in rawBlends) {
        if (doc is! Map) {
          issues.add(const BoxIssue('Blend entry is not an object'));
          continue;
        }
        if (doc['id'] == null) {
          issues.add(const BoxIssue('Blend entry without an id skipped'));
          continue;
        }
        try {
          blends.add(BlendCodec.decode(doc as Map<String, Object?>));
        } catch (_) {
          issues.add(
            BoxIssue('Unreadable blend entry "${doc['name']}" skipped'),
          );
        }
      }
    }
  }
  final rawRecipes = decoded['recipes'];
  if (rawRecipes is! List) {
    return (
      const [],
      blends,
      [...issues, const BoxIssue('Missing recipes list')],
    );
  }
  if (rawRecipes.isEmpty) {
    return (
      const [],
      blends,
      [...issues, const BoxIssue('Box contains no recipes')],
    );
  }
  final recipes = _parseRecipeEntries(rawRecipes, issues);
  return (recipes, blends, issues);
}

/// Decodes every recipe entry. Top-level ids must be unique among
/// entries, and an id claimed by a ref snapshot must carry the
/// same recipe wherever it reappears — snapshots carry origin ids so
/// store propagation can match them, and two different recipes sharing
/// one origin id would make that walk ambiguous. The same recipe beside
/// its own snapshot is the normal export shape, since a recipe
/// inlines its parts by value. The later conflicting entry is skipped
/// with an issue; the first wins.
List<Recipe> _parseRecipeEntries(
  List<Object?> rawRecipes,
  List<BoxIssue> issues,
) {
  final recipes = <Recipe>[];
  final topLevel = <String, String>{};
  final snapshots = <String, String>{};
  for (final doc in rawRecipes) {
    if (doc is! Map) {
      issues.add(const BoxIssue('Recipe entry is not an object'));
      continue;
    }
    final docMap = doc as Map<String, Object?>;
    final id = docMap['id'] as String?;
    if (id != null && topLevel.containsKey(id)) {
      issues.add(BoxIssue('Duplicate recipe id "$id" skipped'));
      continue;
    }
    try {
      final recipe = RecipeCodec.decode(docMap);
      final refs = _refDocs(recipe);
      final canonical = _canonical(recipe);
      final clash = _clashOf(refs, id, canonical, topLevel, snapshots);
      if (clash != null) {
        issues.add(BoxIssue('Duplicate recipe id "$clash" skipped'));
        continue;
      }
      if (id != null) topLevel[id] = canonical;
      for (final (refId, refDoc) in refs) {
        if (refId != null) snapshots[refId] = refDoc;
      }
      recipes.add(recipe);
    } catch (_) {
      issues.add(
        BoxIssue('Unreadable recipe entry "${docMap['name']}" skipped'),
      );
    }
  }
  return recipes;
}

/// The id of the recipe that claims an id twice with different
/// content, or null when [refs], [id] and the seen maps agree.
String? _clashOf(
  List<(String?, String)> refs,
  String? id,
  String canonical,
  Map<String, String> topLevel,
  Map<String, String> snapshots,
) {
  for (final (refId, refDoc) in refs) {
    if (refId == null) continue;
    final known = topLevel[refId] ?? snapshots[refId];
    if (known != null && known != refDoc) return refId;
  }
  if (id == null) return null;
  final own = snapshots[id];
  if (own != null && own != canonical) return id;
  return null;
}

/// Every ref snapshot as (origin id, canonical doc), nested refs
/// included; a ref without an id never matches and cannot collide.
List<(String?, String)> _refDocs(Recipe recipe) {
  final refs = <(String?, String)>[];
  void walk(List<RecipeItem> items) {
    for (final item in items) {
      if (item is! ComponentRef) continue;
      refs.add((item.recipe.id, _canonical(item.recipe)));
      walk(item.recipe.items);
    }
  }

  walk(recipe.items);
  return refs;
}

/// A key-order-stable fingerprint of a recipe doc, so snapshot and
/// top-level copies of one recipe compare equal regardless of how the
/// document was written.
String _canonical(Recipe recipe) => jsonEncode(RecipeCodec.encode(recipe));
