import 'dart:math' as math;

import 'blend.dart';
import 'ingredient.dart';
import 'quantity.dart';
import 'recipe_tree.dart';

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

  /// Scales the amount by `factor^scalingExponent` and snaps the result
  /// to the ingredient's rounding step when it declares one (half eggs,
  /// whole tins). The exponent and the rounding step apply exactly once
  /// per scale pass; the default exponent of 1 scales bit-for-bit like
  /// plain multiplication.
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
class BlendLine {
  const BlendLine(this.blend, this.grams);

  final Blend blend;
  final double grams;

  BlendLine scaledBy(num factor) => BlendLine(blend, grams * factor);
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
    this.blends = const [],
    this.tree,
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

  /// Blends attached at line altitude. Adding one never infers yield or
  /// timestamps; both stay caller-set.
  final List<BlendLine> blends;

  /// The component tree of a compound dish (a layered cake, a filled pie).
  /// Null for a plain recipe; when set, [lines] and [blends] stay empty —
  /// use [Recipe.compound] to build one. Ref snapshots stay untouched by
  /// scaling (see [RecipeTree.scaledBy]); realization is the caller's
  /// single [scaledBy] pass per ref.
  final RecipeTree? tree;

  /// True when this recipe's content is a [RecipeTree] rather than lines.
  bool get isCompound => tree != null;

  /// A compound dish whose content is [tree]; lines and blends stay empty.
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
        lines: const [],
        blends: const [],
        tree: tree,
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
    List<RecipeLine>? lines,
    List<BlendLine>? blends,
    RecipeTree? tree,
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
        blends: blends ?? this.blends,
        tree: tree ?? this.tree,
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
  /// rounding steps and scaling exponents on ingredients are applied
  /// per line, exactly once. A compound's tree scales with the recipe:
  /// ref factors accumulate, snapshots stay untouched.
  Recipe scaledBy(num factor) => Recipe(
        name: name,
        yield: YieldSpec(
          count: yield.count == null ? null : yield.count! * factor,
          totalGrams:
              yield.totalGrams == null ? null : yield.totalGrams! * factor,
        ),
        lines: [for (final line in lines) line.scaledBy(factor)],
        blends: [for (final line in blends) line.scaledBy(factor)],
        tree: tree?.scaledBy(factor),
      );

  /// Returns a copy where every blend line whose blend has [blendId]
  /// points at [replacement], keeping each line's attached grams — the
  /// factors-preserved rule, at blend altitude. Returns this identically
  /// when nothing matches, so callers can skip upserts via [identical];
  /// a blend with a null id never matches.
  Recipe replaceBlend(String blendId, Blend replacement) {
    if (!blends.any((line) => line.blend.id == blendId)) return this;
    return copyWith(
      blends: [
        for (final line in blends)
          line.blend.id == blendId ? BlendLine(replacement, line.grams) : line,
      ],
    );
  }
}
