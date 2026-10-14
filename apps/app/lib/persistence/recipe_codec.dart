import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

/// JSON mapping between engine recipes and their persisted form.
///
/// Ingredients are stored with their conversion data inline so a recipe
/// stays self-contained; [seedIngredients] stay the canonical source for
/// new entry, not for storage.
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
          'gramsPerMl': line.ingredient.gramsPerMl,
          'gramsPerPiece': line.ingredient.gramsPerPiece,
          'roundingStep': line.ingredient.roundingStep,
          'scalingExponent': line.ingredient.scalingExponent,
          'value': line.quantity.amount,
          'unit': line.quantity.unit.name,
        },
    ],
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
      createdAt: _millis(doc['createdAt']),
      updatedAt: _millis(doc['updatedAt']),
      steps: [
        for (final step in doc['steps']! as List<Object?>) step! as String,
      ],
      lines: [
        for (final lineDoc in doc['lines']! as List<Object?>)
          _line(lineDoc! as Map<String, Object?>),
      ],
    );
  }

  static String encodeDoc(Recipe recipe) => jsonEncode(encode(recipe));

  static Recipe decodeDoc(String doc) => decode(jsonDecode(doc) as Map<String, Object?>);

  static RecipeLine _line(Map<String, Object?> doc) => RecipeLine(
    Ingredient(
      doc['ingredient']! as String,
      gramsPerMl: (doc['gramsPerMl'] as num?)?.toDouble(),
      gramsPerPiece: (doc['gramsPerPiece'] as num?)?.toDouble(),
      roundingStep: (doc['roundingStep'] as num?)?.toDouble(),
      scalingExponent: (doc['scalingExponent'] as num?)?.toDouble(),
    ),
    Quantity(
      (doc['value']! as num).toDouble(),
      Unit.values.byName(doc['unit']! as String),
    ),
  );

  static DateTime? _millis(Object? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis as int);
}
