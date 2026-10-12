import 'ingredient.dart';
import 'unit.dart';

/// An amount of something measured in a [Unit].
///
/// Scaling results stay at full precision; rounding is an explicit,
/// separate step ([roundedToNearest]) so the engine never loses information.
class Quantity {
  const Quantity(this.amount, this.unit);

  final double amount;
  final Unit unit;

  /// Converts to another unit.
  ///
  /// Same-kind conversions need no context. Cross-kind conversions
  /// (grams ↔ cups, pieces ↔ grams) need the ingredient's density or
  /// piece weight and throw [ArgumentError] when it is missing.
  Quantity convertTo(Unit target, {Ingredient? ingredient}) {
    if (target == unit) return this;
    if (target.kind == unit.kind) {
      return Quantity(
        amount * unit.canonicalFactor / target.canonicalFactor,
        target,
      );
    }
    return Quantity(bridgedTo(target, ingredient) / target.canonicalFactor,
        target);
  }

  /// This quantity expressed in the canonical base of [target]'s kind
  /// (grams, millilitres, or pieces). Throws [ArgumentError] when the
  /// ingredient lacks the data the bridge needs.
  double bridgedTo(Unit target, Ingredient? ingredient) {
    final grams = gramsOf(ingredient);
    final ml = millilitresOf(ingredient);
    return switch (target.kind) {
      UnitKind.mass when grams != null => grams,
      UnitKind.volume when ml != null => ml,
      UnitKind.count when grams != null && ingredient!.gramsPerPiece != null =>
        grams / ingredient.gramsPerPiece!,
      _ => throw ArgumentError(
          'Cannot convert ${unit.name} to ${target.name} for '
          '"${ingredient?.id ?? "unknown ingredient"}": missing density or '
          'piece weight',
        ),
    };
  }

  /// Canonical grams of this quantity, or null when the ingredient does
  /// not provide the data the conversion needs.
  double? gramsOf(Ingredient? ingredient) => switch (unit.kind) {
        UnitKind.mass => amount * unit.canonicalFactor,
        UnitKind.volume
            when ingredient != null && ingredient.gramsPerMl != null =>
          amount * unit.canonicalFactor * ingredient.gramsPerMl!,
        UnitKind.count
            when ingredient != null && ingredient.gramsPerPiece != null =>
          amount * ingredient.gramsPerPiece!,
        _ => null,
      };

  /// Canonical millilitres of this quantity, or null when the ingredient
  /// does not provide the data the conversion needs.
  double? millilitresOf(Ingredient? ingredient) => switch (unit.kind) {
        UnitKind.volume => amount * unit.canonicalFactor,
        UnitKind.mass
            when ingredient != null && ingredient.gramsPerMl != null =>
          amount * unit.canonicalFactor / ingredient.gramsPerMl!,
        UnitKind.count
            when ingredient != null &&
                ingredient.gramsPerPiece != null &&
                ingredient.gramsPerMl != null =>
          amount * ingredient.gramsPerPiece! / ingredient.gramsPerMl!,
        _ => null,
      };

  /// Returns this quantity multiplied by [factor], keeping the unit.
  Quantity scaledBy(num factor) => Quantity(amount * factor, unit);

  /// Rounds the amount to the nearest multiple of [step] (e.g. 0.5 for
  /// half-eggs). Rounds halves away from zero.
  Quantity roundedToNearest(num step) =>
      Quantity((amount / step).roundToDouble() * step, unit);

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() {
    final shown = amount % 1 == 0 ? amount.toStringAsFixed(0) : '$amount';
    return '$shown ${unit.name}';
  }
}
