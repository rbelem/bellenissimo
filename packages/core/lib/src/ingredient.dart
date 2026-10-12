/// A baking ingredient and the conversion data it carries.
///
/// Both weights are optional because not every conversion needs them:
/// densities bridge mass ↔ volume, piece weights bridge count ↔ mass.
/// Values are approximations; the app lets users override them.
class Ingredient {
  const Ingredient(
    this.id, {
    this.gramsPerMl,
    this.gramsPerPiece,
    this.roundingStep,
  });

  /// Stable identifier, e.g. `flour`, `brown_sugar`, `egg`.
  final String id;

  /// How many grams one millilitre of this ingredient weighs.
  final double? gramsPerMl;

  /// How many grams one piece (one egg, one cookie) weighs.
  final double? gramsPerPiece;

  /// Step to snap scaled amounts to, e.g. 0.5 so eggs scale in halves.
  /// Null keeps scaled amounts exact.
  final double? roundingStep;

  @override
  bool operator ==(Object other) => other is Ingredient && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}
