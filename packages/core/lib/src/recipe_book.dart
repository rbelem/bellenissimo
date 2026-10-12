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
}
