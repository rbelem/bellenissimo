import 'blend.dart';
import 'recipe.dart';

/// A named collection of recipes with identity-based lookups.
///
/// Derivatives are found by [Recipe.parentId], so a new derivative never
/// needs to mutate its parent: index the book, ask for the children.
class RecipeBook {
  RecipeBook(Iterable<Recipe> recipes)
      : recipes = List.unmodifiable(recipes) {
    final seen = <String>{};
    for (final recipe in recipes) {
      final id = recipe.id;
      if (id != null && !seen.add(id)) {
        throw ArgumentError('Duplicate recipe id "$id"');
      }
    }
  }

  final List<Recipe> recipes;

  /// The recipe with this id, or null.
  Recipe? byId(String id) {
    for (final recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  /// Recipes derived from [parentId], in insertion order. A derivative
  /// without its own id is still listed; unknown parents yield [].
  List<Recipe> derivativesOf(String parentId) => [
        for (final recipe in recipes)
          if (recipe.parentId == parentId) recipe,
      ];

  /// Returns a book where every blend line matching [blendId] points at
  /// [replacement]; recipes that don't hold the blend are reused by
  /// identity ([Recipe.replaceBlend]).
  RecipeBook replacingBlend(String blendId, Blend replacement) => RecipeBook([
        for (final recipe in recipes) recipe.replaceBlend(blendId, replacement),
      ]);

  /// Returns a book where every compound holding a ref to [originalId]
  /// points at [replacement]; recipes that don't hold the ref are reused
  /// by identity ([Recipe.replaceRecipe]).
  RecipeBook replacingRecipe(String originalId, Recipe replacement) => RecipeBook([
        for (final recipe in recipes)
          recipe.replaceRecipe(originalId, replacement),
      ]);
}
