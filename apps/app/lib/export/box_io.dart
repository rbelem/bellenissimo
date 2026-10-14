import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

import '../persistence/blend_codec.dart';
import '../persistence/recipe_codec.dart';

/// Version marker of the box document format. Bump on incompatible
/// changes so old apps refuse newer files with a clear issue.
const boxVersion = 2;

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
  if (version != 1 && version != boxVersion) {
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
  final recipes = <Recipe>[];
  for (final doc in rawRecipes) {
    if (doc is! Map) {
      issues.add(const BoxIssue('Recipe entry is not an object'));
      continue;
    }
    try {
      recipes.add(RecipeCodec.decode(doc as Map<String, Object?>));
    } catch (_) {
      issues.add(BoxIssue('Unreadable recipe entry "${doc['name']}" skipped'));
    }
  }
  return (recipes, blends, issues);
}
