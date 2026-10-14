import 'recipe.dart';

/// One part of a compound dish: either a bare ingredient line or a
/// reference to a whole sub-recipe.
sealed class RecipeComponent {
  const RecipeComponent();
}

/// A direct ingredient line, scaled like any [RecipeLine].
class ComponentLeaf extends RecipeComponent {
  const ComponentLeaf(this.line);

  final RecipeLine line;
}

/// A whole sub-recipe used as one component. [recipe] must declare a yield
/// of exactly one unit of the component (one crust, one filling batch);
/// [factor] adapts it to this build.
class ComponentRef extends RecipeComponent {
  const ComponentRef(this.recipe, {required this.factor});

  final Recipe recipe;
  final double factor;
}

/// A dish assembled from components: a pie is a crust plus a filling,
/// a layered cake is stacked sponge and filling refs.
class RecipeTree {
  const RecipeTree({required this.name, required this.components});

  final String name;
  final List<RecipeComponent> components;

  /// Returns a new tree where every [ComponentRef] whose recipe has
  /// [originalId] points at [replacement] with the same factor, so a
  /// derivative (e.g. an egg-free variant) can stand in for the original
  /// inside a compound dish. Refs whose recipe has a null id never match;
  /// factors are untouched — scaling stays [scaledBy]'s job.
  RecipeTree replaceRecipe(String originalId, Recipe replacement) =>
      RecipeTree(
        name: name,
        components: [
          for (final component in components)
            switch (component) {
              ComponentLeaf() => component,
              ComponentRef(recipe: final recipe, factor: final factor) =>
                recipe.id == originalId
                    ? ComponentRef(replacement, factor: factor)
                    : component,
            },
        ],
      );

  /// Scales every component. Leaf lines scale directly; a [ComponentRef]
  /// keeps its recipe instance untouched and only accumulates the factor
  /// (`refFactor * treeFactor`). A scaled compound derivative must keep
  /// resolvable refs — replaceRecipe swaps preserve factors, and pre-scaled
  /// snapshots would silently change the dish's magnitude on a swap — so
  /// the effective quantity is `recipe.scaledBy(factor)`, realized in
  /// exactly one pass (the single-rounding rule) at realization time,
  /// never by chaining scaledBy.
  RecipeTree scaledBy(num factor) => RecipeTree(
        name: name,
        components: [
          for (final component in components)
            switch (component) {
              ComponentLeaf(:final line) => ComponentLeaf(line.scaledBy(factor)),
              ComponentRef(recipe: final recipe, factor: final refFactor) =>
                ComponentRef(recipe, factor: refFactor * factor),
            },
        ],
      );
}

/// Builds an N-layer cake: one sponge ref per layer, one filling ref
/// between adjacent layers, and the topping on top when given.
///
/// [sponge] must yield one layer, [filling] the filling between two
/// adjacent layers, [topping] one cake's top. [spongeFactorPerLayer] is
/// the pan-volume ratio of the target pan.
RecipeTree layeredCake({
  required Recipe sponge,
  required Recipe filling,
  Recipe? topping,
  required int layers,
  required double spongeFactorPerLayer,
}) {
  if (layers < 2) {
    throw ArgumentError('A layered cake needs at least two layers');
  }
  return RecipeTree(
    name: 'layered cake ($layers layers)',
    components: [
      for (var i = 0; i < layers; i++)
        ComponentRef(sponge, factor: spongeFactorPerLayer),
      for (var i = 0; i < layers - 1; i++) ComponentRef(filling, factor: 1.0),
      if (topping != null) ComponentRef(topping, factor: 1.0),
    ],
  );
}
