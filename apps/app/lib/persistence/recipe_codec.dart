import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

import 'blend_codec.dart';

/// JSON mapping between engine recipes and their persisted form.
///
/// Ingredients are stored with their conversion data inline so a recipe
/// stays self-contained; [seedIngredients] stay the canonical source for
/// new entry, not for storage. Attached blends ride the recipe by
/// value: each [BlendLine] serializes its full blend, so a recipe is
/// readable without the blend library.
abstract final class RecipeCodec {
  static Map<String, Object?> encode(Recipe recipe) => {
    'id': recipe.id,
    'name': recipe.name,
    'parentId': recipe.parentId,
    'yield': {
      'count': recipe.yield.count,
      'totalGrams': recipe.yield.totalGrams,
    },
    'createdAt': recipe.createdAt?.millisecondsSinceEpoch,
    'updatedAt': recipe.updatedAt?.millisecondsSinceEpoch,
    'steps': recipe.steps,
    'lines': [
      for (final line in recipe.lines)
        {
          'ingredient': line.ingredient.id,
          ...ingredientFields(line.ingredient),
          'value': line.quantity.amount,
          'unit': line.quantity.unit.name,
        },
    ],
    'blends': [for (final line in recipe.blends) BlendCodec.encodeLine(line)],
  };

  static Recipe decode(Map<String, Object?> doc) {
    final yieldDoc = doc['yield']! as Map<String, Object?>;
    return Recipe(
      id: doc['id'] as String?,
      name: doc['name']! as String,
      parentId: doc['parentId'] as String?,
      yield: YieldSpec(
        count: (yieldDoc['count'] as num?)?.toDouble(),
        totalGrams: (yieldDoc['totalGrams'] as num?)?.toDouble(),
      ),
      createdAt: millisFromDoc(doc['createdAt']),
      updatedAt: millisFromDoc(doc['updatedAt']),
      steps: [
        for (final step in doc['steps']! as List<Object?>) step! as String,
      ],
      lines: [
        for (final lineDoc in doc['lines']! as List<Object?>)
          _line(lineDoc! as Map<String, Object?>),
      ],
      blends: [
        for (final lineDoc
            in doc['blends'] as List<Object?>? ?? const <Object?>[])
          BlendCodec.decodeLine(lineDoc! as Map<String, Object?>),
      ],
    );
  }

  static String encodeDoc(Recipe recipe) => jsonEncode(encode(recipe));

  static Recipe decodeDoc(String doc) =>
      decode(jsonDecode(doc) as Map<String, Object?>);

  /// The conversion fields every inline ingredient carries.
  static Map<String, Object?> ingredientFields(Ingredient ingredient) => {
    'gramsPerMl': ingredient.gramsPerMl,
    'gramsPerPiece': ingredient.gramsPerPiece,
    'roundingStep': ingredient.roundingStep,
    'scalingExponent': ingredient.scalingExponent,
  };

  /// Restores an inline ingredient from [ingredientFields] output.
  static Ingredient ingredientFromDoc(String id, Map<String, Object?> doc) =>
      Ingredient(
        id,
        gramsPerMl: (doc['gramsPerMl'] as num?)?.toDouble(),
        gramsPerPiece: (doc['gramsPerPiece'] as num?)?.toDouble(),
        roundingStep: (doc['roundingStep'] as num?)?.toDouble(),
        scalingExponent: (doc['scalingExponent'] as num?)?.toDouble(),
      );

  static DateTime? millisFromDoc(Object? millis) => millis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(millis as int);

  static RecipeLine _line(Map<String, Object?> doc) => RecipeLine(
    ingredientFromDoc(doc['ingredient']! as String, doc),
    Quantity(
      (doc['value']! as num).toDouble(),
      Unit.values.byName(doc['unit']! as String),
    ),
  );
}
