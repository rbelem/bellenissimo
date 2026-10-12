import 'dart:convert';

import 'ingredient.dart';
import 'quantity.dart';
import 'recipe.dart';
import 'seeds.dart';
import 'unit.dart';

/// One problem found while importing; importing never throws, it
/// collects these instead.
class ImportIssue {
  const ImportIssue(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The outcome of an import: the recipe when the document was usable,
/// plus every issue found along the way.
class RecipeImportResult {
  const RecipeImportResult(this.recipe, this.issues);

  final Recipe? recipe;
  final List<ImportIssue> issues;

  bool get ok => recipe != null;
}

const _vulgarFractions = <String, double>{
  '½': 0.5,
  '¼': 0.25,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
  '⅛': 0.125,
  '⅜': 0.375,
  '⅝': 0.625,
  '⅞': 0.875,
};

const _unitAliases = <String, Unit>{
  'g': Unit.g,
  'gram': Unit.g,
  'grams': Unit.g,
  'kg': Unit.kg,
  'kilogram': Unit.kg,
  'kilograms': Unit.kg,
  'kilos': Unit.kg,
  'oz': Unit.oz,
  'ounce': Unit.oz,
  'ounces': Unit.oz,
  'lb': Unit.lb,
  'lbs': Unit.lb,
  'pound': Unit.lb,
  'pounds': Unit.lb,
  'ml': Unit.ml,
  'millilitre': Unit.ml,
  'millilitres': Unit.ml,
  'milliliter': Unit.ml,
  'milliliters': Unit.ml,
  'l': Unit.l,
  'litre': Unit.l,
  'litres': Unit.l,
  'liter': Unit.l,
  'liters': Unit.l,
  'tsp': Unit.tsp,
  'teaspoon': Unit.tsp,
  'teaspoons': Unit.tsp,
  'tbsp': Unit.tbsp,
  'tablespoon': Unit.tbsp,
  'tablespoons': Unit.tbsp,
  'cup': Unit.cup,
  'cups': Unit.cup,
  'fl oz': Unit.flOz,
  'fluid ounce': Unit.flOz,
  'fluid ounces': Unit.flOz,
};

final _whitespace = RegExp(r'\s+');

RecipeImportResult importRecipeJson(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    return const RecipeImportResult(null, [ImportIssue('Malformed JSON')]);
  }
  if (decoded is Map && _hasRecipeType(decoded)) {
    return _importRecipeNode(decoded);
  }
  final node = _findRecipe(decoded);
  if (node == null) {
    return const RecipeImportResult(
      null,
      [ImportIssue('No schema.org/Recipe object found')],
    );
  }
  return _importRecipeNode(node);
}

Map<dynamic, dynamic>? _findRecipe(Object? decoded) {
  if (decoded is List) {
    for (final node in decoded) {
      final found = _findRecipe(node);
      if (found != null) return found;
    }
    return null;
  }
  if (decoded is! Map) return null;
  if (_hasRecipeType(decoded)) return decoded;
  final graph = decoded['@graph'];
  if (graph is List) {
    for (final node in graph) {
      if (node is Map && _hasRecipeType(node)) return node;
    }
  }
  return _nodeWithIngredients(decoded);
}

Map<dynamic, dynamic>? _nodeWithIngredients(Object? node) {
  if (node is Map) {
    if (node.containsKey('recipeIngredient')) return node;
    for (final value in node.values) {
      final found = _nodeWithIngredients(value);
      if (found != null) return found;
    }
  } else if (node is List) {
    for (final item in node) {
      final found = _nodeWithIngredients(item);
      if (found != null) return found;
    }
  }
  return null;
}

RecipeImportResult _importRecipeNode(Map<dynamic, dynamic> node) {
  final issues = <ImportIssue>[];
  final name = node['name'];
  final hasName = name is String && name.trim().isNotEmpty;
  if (!hasName) issues.add(const ImportIssue('Missing recipe name'));

  final lines = <RecipeLine>[];
  final rawIngredients = node['recipeIngredient'];
  if (rawIngredients is List) {
    for (final raw in rawIngredients) {
      final line = _parseLine(raw, issues);
      if (line != null) lines.add(line);
    }
  } else {
    issues.add(const ImportIssue('Missing recipeIngredient array'));
  }

  if (!hasName || lines.isEmpty) {
    return RecipeImportResult(null, issues);
  }
  final yieldSpec = _parseYield(node['recipeYield']);
  if (yieldSpec == null) {
    issues.add(const ImportIssue('Missing or unparseable recipeYield'));
  }
  return RecipeImportResult(
    Recipe(name: name, yield: yieldSpec ?? const YieldSpec(), lines: lines),
    issues,
  );
}

YieldSpec? _parseYield(Object? raw) {
  if (raw is! String) return null;
  final words = raw
      .trim()
      .split(_whitespace)
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return null;
  final first = words.first.toLowerCase();
  final mergedGrams = _mergedMassGrams(first);
  if (mergedGrams != null) return YieldSpec(totalGrams: mergedGrams);
  final amount = _parseAmount(first);
  if (amount == null) return null;
  if (words.length >= 2) {
    final unit = _unitAliases[words[1].toLowerCase()];
    if (unit != null && unit.kind == UnitKind.mass) {
      return YieldSpec(totalGrams: amount * unit.canonicalFactor);
    }
  }
  return YieldSpec(count: amount);
}

/// Recognises yield forms where the mass unit is glued to the number,
/// like `900g` or `1.5kg`; the longest suffix wins so `kg` beats `g`.
double? _mergedMassGrams(String token) {
  const suffixes = <String, Unit>{
    'kg': Unit.kg,
    'oz': Unit.oz,
    'lb': Unit.lb,
    'g': Unit.g,
  };
  for (final entry in suffixes.entries) {
    if (!token.endsWith(entry.key)) continue;
    final prefix = token.substring(0, token.length - entry.key.length);
    final amount = double.tryParse(prefix);
    if (amount != null) return amount * entry.value.canonicalFactor;
  }
  return null;
}

bool _hasRecipeType(Map<dynamic, dynamic> node) {
  final type = node['@type'];
  if (type is String) return type.toLowerCase() == 'recipe';
  if (type is List) {
    return type.any((t) => t is String && t.toLowerCase() == 'recipe');
  }
  return false;
}

RecipeLine? _parseLine(Object? raw, List<ImportIssue> issues) {
  if (raw is! String) {
    issues.add(const ImportIssue('Non-string recipeIngredient entry'));
    return null;
  }
  final words = raw
      .trim()
      .split(_whitespace)
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    issues.add(const ImportIssue('Empty recipeIngredient entry'));
    return null;
  }
  final amount = _parseAmount(words.first);
  final rest = _dropRangeTail(words.sublist(1));
  if (amount == null || amount <= 0) {
    issues.add(ImportIssue('No amount in "$raw"'));
    return null;
  }
  if (rest.isEmpty) {
    issues.add(ImportIssue('No ingredient name in "$raw"'));
    return null;
  }
  final split = _splitUnit(rest);
  if (split == null) {
    issues.add(ImportIssue('Unknown unit in "$raw"'));
    return null;
  }
  final (unit, nameWords) = split;
  if (nameWords.isEmpty) {
    issues.add(ImportIssue('No ingredient name in "$raw"'));
    return null;
  }
  final id = nameWords.map((word) => word.toLowerCase()).join('_');
  final ingredient = seedIngredients[id] ?? Ingredient(id);
  return RecipeLine(ingredient, Quantity(amount, unit));
}

List<String> _dropRangeTail(List<String> rest) {
  if (rest.length >= 2 &&
      rest[0].toLowerCase() == 'to' &&
      _parseAmount(rest[1]) != null) {
    return rest.sublist(2);
  }
  return rest;
}

(Unit, List<String>)? _splitUnit(List<String> rest) {
  if (rest.length >= 2) {
    final twoWord = _unitAliases['${rest[0]} ${rest[1]}'.toLowerCase()];
    if (twoWord != null) return (twoWord, rest.sublist(2));
  }
  final first = _unitAliases[rest[0].toLowerCase()];
  if (first != null) return (first, rest.sublist(1));
  if (rest.length == 1) return (Unit.piece, rest);
  return null;
}

double? _parseAmount(String token) {
  var t = token;
  final dash = t.indexOf('-');
  if (dash > 0) t = t.substring(0, dash);
  var i = 0;
  while (i < t.length && _isDigitOrDot(t.codeUnitAt(i))) {
    i++;
  }
  final whole = double.tryParse(t.substring(0, i));
  final rest = t.substring(i);
  if (rest.isEmpty) return whole;
  if (rest.length == 1) {
    final fraction = _vulgarFractions[rest];
    if (fraction != null) return (whole ?? 0) + fraction;
  }
  return null;
}

bool _isDigitOrDot(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) || codeUnit == 0x2E;
