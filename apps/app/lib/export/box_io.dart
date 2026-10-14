import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

import '../persistence/recipe_codec.dart';

/// Version marker of the box document format. Bump on incompatible
/// changes so old apps refuse newer files with a clear issue.
const boxVersion = 1;

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

/// The outcome of a box import: how many recipes were written and
/// every issue found along the way.
class BoxImportResult {
  const BoxImportResult(this.imported, this.issues);

  final int imported;
  final List<BoxIssue> issues;

  bool get ok => issues.isEmpty;
}

/// Serializes a whole box: every recipe as its codec doc, plus the
/// version marker.
String encodeBox(List<Recipe> recipes) =>
    const JsonEncoder.withIndent('  ').convert({
      'version': boxVersion,
      'recipes': [for (final recipe in recipes) RecipeCodec.encode(recipe)],
    });

/// Parses a box document into the usable recipes plus every issue.
/// An empty recipe list paired with issues means the payload was
/// rejected outright and the store must stay untouched.
(List<Recipe>, List<BoxIssue>) parseBox(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    return (const [], [BoxIssue('Malformed JSON')]);
  }
  if (decoded is! Map) {
    return (const [], [BoxIssue('Not a box document')]);
  }
  final version = decoded['version'];
  if (version is! int) {
    return (const [], [BoxIssue('Missing box version marker')]);
  }
  if (version != boxVersion) {
    return (const [], [BoxIssue('Unsupported box version: $version')]);
  }
  final rawRecipes = decoded['recipes'];
  if (rawRecipes is! List) {
    return (const [], [BoxIssue('Missing recipes list')]);
  }
  if (rawRecipes.isEmpty) {
    return (const [], [BoxIssue('Box contains no recipes')]);
  }
  final issues = <BoxIssue>[];
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
  return (recipes, issues);
}
