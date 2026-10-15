import 'dart:math' as math;

import 'blend.dart';
import 'ingredient.dart';
import 'quantity.dart';

/// How much a recipe makes, in user-meaningful dimensions.
///
/// A recipe declares every dimension it can be scaled by: 24 cookies,
/// 900 g of dough, or both. At least one dimension must be non-null.
class YieldSpec {
  const YieldSpec({this.count, this.totalGrams});

  /// Number of pieces the recipe makes (cookies, buns).
  final double? count;

  /// Total mass of what the recipe makes, in grams.
  final double? totalGrams;
}

/// One item of a [Recipe]: an ingredient line, a blend use, or a
/// reference to another recipe.
///
/// The seal forces every consumer to handle all three kinds. Each kind
/// carries its own scaling rule, applied exactly once per [scaledBy]
/// pass (the single-rounding rule).
sealed class RecipeItem {
  const RecipeItem();

  RecipeItem scaledBy(num factor);
}

/// One ingredient and how much of it a [Recipe] needs.
class RecipeLine extends RecipeItem {
  const RecipeLine(this.ingredient, this.quantity);

  final Ingredient ingredient;
  final Quantity quantity;

  /// Scales the amount by `factor^scalingExponent` and snaps the result
  /// to the ingredient's rounding step when it declares one (half eggs,
  /// whole tins). The exponent and the rounding step apply exactly once
  /// per scale pass; the default exponent of 1 scales bit-for-bit like
  /// plain multiplication.
  @override
  RecipeLine scaledBy(num factor) {
    final exponent = ingredient.scalingExponent ?? 1.0;
    final scaled =
        quantity.scaledBy(exponent == 1.0 ? factor : math.pow(factor, exponent));
    final step = ingredient.roundingStep;
    return RecipeLine(ingredient, step == null ? scaled : scaled.roundedToNearest(step));
  }
}

/// One blend and how much of it a [Recipe] needs, attached at line
/// altitude beside the [RecipeLine]s.
///
/// Scaling multiplies [grams] exactly. Per-gram blend ratios are
/// scale-invariant, so no rounding step ever applies here — snapping a
/// scaled blend line would compound with the recipe-level rounding rule.
class BlendLine extends RecipeItem {
  const BlendLine(this.blend, this.grams);

  final Blend blend;
  final double grams;

  @override
  BlendLine scaledBy(num factor) => BlendLine(blend, grams * factor);
}

/// An immutable recipe: items plus what it yields.
///
/// An item is an ingredient line, a blend use, or a reference to
/// another recipe, in display order. Scaling never mutates; [scaledBy]
/// returns a new recipe and the original stays untouched.
class Recipe {
  const Recipe({
    required this.name,
    required this.yield,
    required this.items,
    this.id,
    this.parentId,
    this.steps = const [],
    this.createdAt,
    this.updatedAt,
  });

  /// Stable identity within a [RecipeBook]; null for ad-hoc recipes.
  final String? id;

  /// [id] of the recipe this one derives from (e.g. an egg-free variant).
  final String? parentId;

  /// Ordered preparation steps. The engine treats them as display data.
  final List<String> steps;

  /// Set by the caller on creation; the engine never infers times.
  final DateTime? createdAt;

  /// Set by the caller when a recipe's content changes.
  final DateTime? updatedAt;

  final String name;
  final YieldSpec yield;

  /// Every item in display order: ingredient lines, blend uses, and
  /// references to other recipes. Adding one never infers yield or
  /// timestamps; both stay caller-set.
  final List<RecipeItem> items;

  /// True when this recipe references another recipe. A recipe holding
  /// only ingredient lines and blends is never compound.
  bool get isCompound => items.any((item) => item is ComponentRef);

  /// A compound dish whose content is [tree]; the tree's components
  /// become this recipe's items, in order. The result reports compound
  /// only when the tree holds refs — a tree of bare lines is a plain
  /// recipe with ordered items.
  factory Recipe.compound({
    required String name,
    required YieldSpec yield,
    required RecipeTree tree,
    String? id,
    String? parentId,
    List<String> steps = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Recipe(
        name: name,
        yield: yield,
        items: tree.components,
        id: id,
        parentId: parentId,
        steps: steps,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  /// Returns a copy with the given fields replaced and everything else
  /// preserved. Use this for derivatives and edits — never mutate lists.
  Recipe copyWith({
    String? name,
    YieldSpec? yield,
    List<RecipeItem>? items,
    String? id,
    String? parentId,
    List<String>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Recipe(
        name: name ?? this.name,
        yield: yield ?? this.yield,
        items: items ?? this.items,
        id: id ?? this.id,
        parentId: parentId ?? this.parentId,
        steps: steps ?? this.steps,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// The factor that adapts this recipe to a target yield dimension.
  /// Give exactly one target.
  double factorTo({double? targetCount, double? targetTotalGrams}) {
    if ((targetCount == null) == (targetTotalGrams == null)) {
      throw ArgumentError('Give exactly one target dimension');
    }
    if (targetCount != null) {
      final base = yield.count;
      if (base == null) {
        throw ArgumentError('Recipe "$name" declares no count yield');
      }
      return targetCount / base;
    }
    final base = yield.totalGrams;
    if (base == null) {
      throw ArgumentError('Recipe "$name" declares no totalGrams yield');
    }
    return targetTotalGrams! / base;
  }

  /// Returns the recipe scaled by [factor]. Yield dimensions scale too;
  /// every item scales by its own rule, exactly once. A ref's factor
  /// accumulates while its snapshot stays untouched.
  Recipe scaledBy(num factor) => Recipe(
        name: name,
        yield: YieldSpec(
          count: yield.count == null ? null : yield.count! * factor,
          totalGrams:
              yield.totalGrams == null ? null : yield.totalGrams! * factor,
        ),
        items: [for (final item in items) item.scaledBy(factor)],
      );

  /// Returns a copy where every ref to [originalId] points at
  /// [replacement], each factor preserved — the same swap as
  /// [RecipeTree.replaceRecipe] at recipe altitude. Returns this when no
  /// item holds that id, so callers can skip upserts via [identical];
  /// timestamps stay caller-set.
  Recipe replaceRecipe(String originalId, Recipe replacement) {
    if (!items.any(
      (item) => item is ComponentRef && item.recipe.id == originalId,
    )) {
      return this;
    }
    return copyWith(
      items: [
        for (final item in items)
          item is ComponentRef && item.recipe.id == originalId
              ? ComponentRef(replacement, factor: item.factor)
              : item,
      ],
    );
  }

  /// Returns a copy where every blend use whose blend has [blendId]
  /// points at [replacement], keeping each use's grams. Returns this
  /// identically when nothing matches, so callers can skip upserts via
  /// [identical]; a blend with a null id never matches.
  Recipe replaceBlend(String blendId, Blend replacement) {
    if (!items.any(
      (item) => item is BlendLine && item.blend.id == blendId,
    )) {
      return this;
    }
    return copyWith(
      items: [
        for (final item in items)
          item is BlendLine && item.blend.id == blendId
              ? BlendLine(replacement, item.grams)
              : item,
      ],
    );
  }
}

/// A whole sub-recipe used as one item. [recipe] must declare a yield
/// of exactly one unit of the component (one crust, one filling batch);
/// [factor] adapts it to this build.
///
/// Scaling accumulates the factor and leaves the snapshot untouched, so
/// a later [Recipe.replaceRecipe] swap preserves the dish's magnitude.
class ComponentRef extends RecipeItem {
  const ComponentRef(this.recipe, {required this.factor});

  final Recipe recipe;
  final double factor;

  @override
  ComponentRef scaledBy(num factor) =>
      ComponentRef(recipe, factor: factor * this.factor);
}

/// A dish assembled from items: a pie is a crust plus a filling,
/// a layered cake is stacked sponge and filling refs.
class RecipeTree {
  const RecipeTree({required this.name, required this.components});

  final String name;
  final List<RecipeItem> components;

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
              RecipeLine() => component,
              BlendLine() => component,
              ComponentRef(recipe: final recipe, factor: final factor) =>
                recipe.id == originalId
                    ? ComponentRef(replacement, factor: factor)
                    : component,
            },
        ],
      );

  /// Scales every item through its own [RecipeItem.scaledBy] rule, in
  /// exactly one pass.
  RecipeTree scaledBy(num factor) => RecipeTree(
        name: name,
        components: [
          for (final component in components) component.scaledBy(factor),
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
