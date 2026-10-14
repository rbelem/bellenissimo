import 'dart:convert';

import 'package:bellenissimos_core/core.dart';

import 'blend_codec.dart';

/// JSON mapping between engine recipes and their persisted form.
///
/// Ingredients are stored with their conversion data inline so a recipe
/// stays self-contained; [seedIngredients] stay the canonical source for
/// new entry, not for storage. Attached blends ride the recipe by
/// value: each [BlendLine] serializes its full blend, so a recipe is
/// readable without the blend library. A compound's tree rides the
/// recipe the same way: component recipes serialize inline by value,
/// so a compound imports and reads without its parts and deleting a
/// part cannot dangle a ref.
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
    'lines': [for (final line in recipe.lines) _lineDoc(line)],
    'blends': [for (final line in recipe.blends) BlendCodec.encodeLine(line)],
    if (recipe.tree != null) 'tree': _treeDoc(recipe.tree!),
  };

  static Recipe decode(Map<String, Object?> doc) {
    final yieldDoc = doc['yield']! as Map<String, Object?>;
    final id = doc['id'] as String?;
    final name = doc['name']! as String;
    final parentId = doc['parentId'] as String?;
    final yield = YieldSpec(
      count: (yieldDoc['count'] as num?)?.toDouble(),
      totalGrams: (yieldDoc['totalGrams'] as num?)?.toDouble(),
    );
    final createdAt = millisFromDoc(doc['createdAt']);
    final updatedAt = millisFromDoc(doc['updatedAt']);
    final steps = [
      for (final step in doc['steps']! as List<Object?>) step! as String,
    ];
    final lines = [
      for (final lineDoc in doc['lines']! as List<Object?>)
        _line(lineDoc! as Map<String, Object?>),
    ];
    final blends = [
      for (final lineDoc
          in doc['blends'] as List<Object?>? ?? const <Object?>[])
        BlendCodec.decodeLine(lineDoc! as Map<String, Object?>),
    ];
    final treeDoc = doc['tree'];
    if (treeDoc == null) {
      return Recipe(
        id: id,
        name: name,
        parentId: parentId,
        yield: yield,
        createdAt: createdAt,
        updatedAt: updatedAt,
        steps: steps,
        lines: lines,
        blends: blends,
      );
    }
    if (lines.isNotEmpty || blends.isNotEmpty) {
      throw ArgumentError('A compound recipe carries no lines or blends');
    }
    return Recipe.compound(
      id: id,
      name: name,
      parentId: parentId,
      yield: yield,
      createdAt: createdAt,
      updatedAt: updatedAt,
      steps: steps,
      tree: _tree(treeDoc as Map<String, Object?>),
    );
  }

  static Map<String, Object?> _treeDoc(RecipeTree tree) => {
    'name': tree.name,
    'components': [for (final component in tree.components) _componentDoc(component)],
  };

  static Map<String, Object?> _componentDoc(RecipeComponent component) =>
      switch (component) {
        ComponentLeaf(:final line) => {'leaf': _lineDoc(line)},
        ComponentRef(:final recipe, :final factor) => {
          'ref': encode(recipe),
          'factor': factor,
        },
      };

  static RecipeTree _tree(Map<String, Object?> doc) => RecipeTree(
    name: doc['name']! as String,
    components: [
      for (final componentDoc in doc['components']! as List<Object?>)
        _component(componentDoc! as Map<String, Object?>),
    ],
  );

  static RecipeComponent _component(Map<String, Object?> doc) {
    final leaf = doc['leaf'];
    if (leaf != null) {
      return ComponentLeaf(_line(leaf as Map<String, Object?>));
    }
    final ref = doc['ref'];
    if (ref != null) {
      return ComponentRef(
        decode(ref as Map<String, Object?>),
        factor: (doc['factor']! as num).toDouble(),
      );
    }
    throw ArgumentError('A tree component is neither a leaf nor a ref');
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

  static Map<String, Object?> _lineDoc(RecipeLine line) => {
    'ingredient': line.ingredient.id,
    ...ingredientFields(line.ingredient),
    'value': line.quantity.amount,
    'unit': line.quantity.unit.name,
  };
}
