import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  group('seed ingredient table', () {
    test('flour converts 1 cup to about 120 g', () {
      final g = const Quantity(1, Unit.cup)
          .convertTo(Unit.g, ingredient: seedIngredients['flour']!)
          .amount;
      expect(g, closeTo(120, 1));
    });

    test('granulated sugar converts 1 cup to about 200 g', () {
      final g = const Quantity(1, Unit.cup)
          .convertTo(Unit.g, ingredient: seedIngredients['sugar']!)
          .amount;
      expect(g, closeTo(200, 1));
    });

    test('butter converts 1 cup to about 227 g', () {
      final g = const Quantity(1, Unit.cup)
          .convertTo(Unit.g, ingredient: seedIngredients['butter']!)
          .amount;
      expect(g, closeTo(227, 1));
    });

    test('one egg weighs about 50 g', () {
      final g = const Quantity(1, Unit.piece)
          .convertTo(Unit.g, ingredient: seedIngredients['egg']!)
          .amount;
      expect(g, closeTo(50, 0.1));
    });

    test('seed yeast converts a teaspoon to about 3 g', () {
      final g = const Quantity(1, Unit.tsp)
          .convertTo(Unit.g, ingredient: seedIngredients['yeast']!)
          .amount;
      expect(g, closeTo(3.0, 0.01));
    });

    test('seed yeast scales leavening sub-linearly', () {
      expect(seedIngredients['yeast']!.scalingExponent, 0.7);
    });

    test('every seed provides at least one conversion datum', () {
      for (final entry in seedIngredients.entries) {
        final ing = entry.value;
        final hasData =
            ing.gramsPerMl != null || ing.gramsPerPiece != null;
        expect(hasData, isTrue, reason: '$entry has no conversion data');
      }
    });

    test('seed ids match their map keys', () {
      for (final entry in seedIngredients.entries) {
        expect(entry.value.id, entry.key);
      }
    });
  });
}
