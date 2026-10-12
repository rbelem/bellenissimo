import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  const applesauce = Ingredient('applesauce');
  const butter = Ingredient('butter', gramsPerMl: 0.95);
  const egg = Ingredient('egg', gramsPerPiece: 50);
  const flaxEgg = Ingredient('flax_egg', gramsPerPiece: 60);

  group('applySubstitution', () {
    test('mass line converts by ratio and carries the note', () {
      final result = applySubstitution(
        RecipeLine(butter, const Quantity(200, Unit.g)),
        [
          Substitution(
            'butter',
            applesauce,
            gramsPerGram: 0.5,
            note: 'reduce oven by 10C',
          ),
        ],
      );
      expect(result, isNotNull);
      expect(result!.line.ingredient, applesauce);
      expect(result.line.quantity, const Quantity(100, Unit.g));
      expect(result.note, 'reduce oven by 10C');
    });

    test('piece-based replacement yields exact unrounded pieces', () {
      final result = applySubstitution(
        RecipeLine(egg, const Quantity(1, Unit.piece)),
        [Substitution('egg', flaxEgg, gramsPerGram: 1.0)],
      );
      expect(result, isNotNull);
      expect(result!.line.ingredient, flaxEgg);
      expect(result.line.quantity.amount, closeTo(50 / 60, 1e-12));
      expect(result.line.quantity.unit, Unit.piece);
      expect(result.note, isNull);
    });

    test('returns null when no option matches the ingredient id', () {
      final result = applySubstitution(
        RecipeLine(butter, const Quantity(200, Unit.g)),
        [Substitution('margarine', applesauce, gramsPerGram: 1.0)],
      );
      expect(result, isNull);
    });

    test('returns null when the line mass is unresolvable', () {
      final result = applySubstitution(
        RecipeLine(
          const Ingredient('mystery_powder'),
          const Quantity(1, Unit.cup),
        ),
        [Substitution('mystery_powder', applesauce, gramsPerGram: 1.0)],
      );
      expect(result, isNull);
    });
  });
}
