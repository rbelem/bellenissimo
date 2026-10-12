import 'ingredient.dart';
import 'quantity.dart';
import 'recipe.dart';
import 'unit.dart';

/// Replaces one ingredient with another using a mass-equivalence ratio.
class Substitution {
  const Substitution(
    this.replacesId,
    this.withIngredient, {
    required this.gramsPerGram,
    this.note,
  });

  /// Id of the ingredient being replaced, matched against [RecipeLine].
  final String replacesId;

  /// The ingredient substituted in.
  final Ingredient withIngredient;

  /// Grams of the replacement that stand in for 1 g of the original.
  final double gramsPerGram;

  /// Cooking advice carried through to the substituted line, e.g.
  /// "reduce oven by 10C".
  final String? note;
}

/// A [RecipeLine] after substitution, plus the substitution's note.
class SubstitutedLine {
  const SubstitutedLine(this.line, this.note);

  final RecipeLine line;

  final String? note;
}

/// Applies the first substitution matching [line]'s ingredient.
///
/// Returns null when no option matches, or when the line's mass cannot
/// be resolved: substituting safely needs a mass equivalence.
SubstitutedLine? applySubstitution(RecipeLine line, List<Substitution> options) {
  for (final option in options) {
    if (option.replacesId != line.ingredient.id) continue;
    final grams = line.quantity.gramsOf(line.ingredient);
    if (grams == null) return null;
    final replacementGrams = grams * option.gramsPerGram;
    final pieceWeight = option.withIngredient.gramsPerPiece;
    final quantity = pieceWeight == null
        ? Quantity(replacementGrams, Unit.g)
        : Quantity(replacementGrams / pieceWeight, Unit.piece);
    return SubstitutedLine(RecipeLine(option.withIngredient, quantity),
        option.note);
  }
  return null;
}
