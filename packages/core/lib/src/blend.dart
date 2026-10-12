import 'ingredient.dart';
import 'quantity.dart';
import 'unit.dart';

void _checkParts({
  required Map<Ingredient, double> grams,
  required Map<Ingredient, double> perGram,
  required String className,
}) {
  if (grams.isEmpty || perGram.isEmpty) {
    throw ArgumentError('$className needs at least one ingredient');
  }
  if (grams.length != perGram.length ||
      !grams.keys.every(perGram.containsKey)) {
    throw ArgumentError('$className maps must cover the same ingredients');
  }
  for (final entry in grams.entries) {
    if (entry.value <= 0) {
      throw ArgumentError(
        '$className grams for "${entry.key.id}" must be positive',
      );
    }
  }
}

/// A mix of sweeteners standing in for sugar.
///
/// Sweetness values are relative to sucrose (sugar = 1.0, e.g.
/// erythritol 0.7), so blends of high-intensity sweeteners can exceed 1.
class SweetenerBlend {
  factory SweetenerBlend({
    required Map<Ingredient, double> grams,
    required Map<Ingredient, double> sweetnessPerGram,
  }) {
    _checkParts(
      grams: grams,
      perGram: sweetnessPerGram,
      className: 'SweetenerBlend',
    );
    return SweetenerBlend._(
      Map.of(grams),
      Map.of(sweetnessPerGram),
    );
  }

  SweetenerBlend._(this._grams, this._sweetnessPerGram);

  final Map<Ingredient, double> _grams;
  final Map<Ingredient, double> _sweetnessPerGram;

  double get totalGrams => _grams.values.fold(0.0, (sum, g) => sum + g);

  double get sucroseEquivalentPerGram {
    final sweetened = _grams.entries.fold(
      0.0,
      (sum, entry) => sum + entry.value * _sweetnessPerGram[entry.key]!,
    );
    return sweetened / totalGrams;
  }

  /// True when the blend is far weaker per gram than sugar.
  ///
  /// The 0.8 cutoff is a heuristic: below it, matching sugar's sweetness
  /// needs so much extra mass that the recipe's bulk and structure shift
  /// beyond what a plain swap covers.
  bool get losesBulk => sucroseEquivalentPerGram < 0.8;

  /// The blend mass that replaces [sugar], keeping sucrose sweetness.
  Quantity replaceSugar(Quantity sugar, {required Ingredient sugarInfo}) {
    final sugarGrams = sugar.gramsOf(sugarInfo);
    if (sugarGrams == null) {
      throw ArgumentError(
        'Cannot resolve ${sugar.amount} ${sugar.unit.name} of '
        '"${sugarInfo.id}" to grams',
      );
    }
    return Quantity(sugarGrams / sucroseEquivalentPerGram, Unit.g);
  }
}

/// A mix of flours with a blended protein content.
class FlourMix {
  factory FlourMix({
    required Map<Ingredient, double> grams,
    required Map<Ingredient, double> proteinPct,
  }) {
    _checkParts(grams: grams, perGram: proteinPct, className: 'FlourMix');
    return FlourMix._(Map.of(grams), Map.of(proteinPct));
  }

  FlourMix._(this._grams, this._proteinPct);

  final Map<Ingredient, double> _grams;
  final Map<Ingredient, double> _proteinPct;

  double get totalGrams => _grams.values.fold(0.0, (sum, g) => sum + g);

  /// Protein percentage averaged across the mix, weighted by grams.
  double get proteinPct {
    final total = totalGrams;
    return _grams.entries.fold(
      0.0,
      (sum, entry) => sum + entry.value * _proteinPct[entry.key]! / total,
    );
  }

  /// Water percentage for a bread dough from this mix.
  ///
  /// Heuristic: 58% base hydration for a 10% protein flour, plus 3 points
  /// of hydration per point of protein, clamped to [55, 85] because the
  /// linear rule overshoots at the extremes (gluten flours, cake flours).
  double breadHydrationPct() {
    final raw = 58 + (proteinPct - 10) * 3;
    return raw.clamp(55, 85).toDouble();
  }
}
