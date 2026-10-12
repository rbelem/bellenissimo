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

/// One ingredient and how much of it a [Recipe] needs.
class RecipeLine {
  const RecipeLine(this.ingredient, this.quantity);

  final Ingredient ingredient;
  final Quantity quantity;

  /// Scales the amount and snaps it to the ingredient's rounding step
  /// when it declares one (half eggs, whole tins).
  RecipeLine scaledBy(num factor) {
    final scaled = quantity.scaledBy(factor);
    final step = ingredient.roundingStep;
    return RecipeLine(ingredient, step == null ? scaled : scaled.roundedToNearest(step));
  }
}

/// An immutable recipe: lines plus what it yields.
///
/// Scaling never mutates; [scaledBy] returns a new recipe and the
/// original stays untouched.
class Recipe {
  const Recipe({
    required this.name,
    required this.yield,
    required this.lines,
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
  final List<RecipeLine> lines;

  /// Returns a copy with the given fields replaced and everything else
  /// preserved. Use this for derivatives and edits — never mutate lists.
  Recipe copyWith({
    String? name,
    YieldSpec? yield,
    List<RecipeLine>? lines,
    String? id,
    String? parentId,
    List<String>? steps,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Recipe(
        name: name ?? this.name,
        yield: yield ?? this.yield,
        lines: lines ?? this.lines,
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
  /// rounding steps on ingredients (half eggs) are applied per line.
  Recipe scaledBy(num factor) => Recipe(
        name: name,
        yield: YieldSpec(
          count: yield.count == null ? null : yield.count! * factor,
          totalGrams:
              yield.totalGrams == null ? null : yield.totalGrams! * factor,
        ),
        lines: [for (final line in lines) line.scaledBy(factor)],
      );
}
