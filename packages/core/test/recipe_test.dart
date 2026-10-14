import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  final eggsSnapped = const Ingredient('egg', gramsPerPiece: 50, roundingStep: 0.5);

  final cookieRecipe = Recipe(
    name: 'butter cookies',
    yield: const YieldSpec(count: 24),
    lines: [
      const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      const RecipeLine(Ingredient('butter', gramsPerMl: 0.95), Quantity(200, Unit.g)),
      RecipeLine(eggsSnapped, const Quantity(1, Unit.piece)),
    ],
  );

  final breadRecipe = Recipe(
    name: 'sandwich loaf',
    yield: const YieldSpec(totalGrams: 900),
    lines: [
      const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(500, Unit.g)),
      const RecipeLine(Ingredient('water', gramsPerMl: 1.0), Quantity(320, Unit.g)),
    ],
  );

  group('scale factor from yield', () {
    test('36 cookies from a 24-cookie recipe scales 1.5×', () {
      expect(cookieRecipe.factorTo(targetCount: 36), 1.5);
    });

    test('1350 g of dough from a 900 g recipe scales 1.5×', () {
      expect(breadRecipe.factorTo(targetTotalGrams: 1350), 1.5);
    });

    test('giving no target throws', () {
      expect(() => cookieRecipe.factorTo(), throwsArgumentError);
    });

    test('giving two targets throws', () {
      expect(
        () => cookieRecipe.factorTo(targetCount: 36, targetTotalGrams: 900),
        throwsArgumentError,
      );
    });

    test('asking for count on a recipe without count yield throws', () {
      expect(
        () => breadRecipe.factorTo(targetCount: 2),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('sandwich loaf'),
        )),
      );
    });

    test('asking for total grams on a recipe without it throws', () {
      expect(
        () => cookieRecipe.factorTo(targetTotalGrams: 900),
        throwsArgumentError,
      );
    });
  });

  group('scaled recipes', () {
    test('scaling by 1.5 scales every line', () {
      final scaled = cookieRecipe.scaledBy(1.5);
      expect(scaled.lines[0].quantity.amount, 375);
      expect(scaled.lines[1].quantity.amount, 300);
    });

    test('eggs snap to half eggs when the ingredient declares a step', () {
      final scaled = cookieRecipe.scaledBy(1.25);
      expect(scaled.lines[2].quantity.amount, 1.5);
    });

    test('ingredients without a rounding step stay exact', () {
      final scaled = breadRecipe.scaledBy(1.1);
      expect(scaled.lines[0].quantity.amount, closeTo(550, 0.001));
    });

    test('scaled yield reports the new count', () {
      final scaled = cookieRecipe.scaledBy(1.5);
      expect(scaled.yield.count, 36);
    });

    test('scaled yield reports the new total grams', () {
      final scaled = breadRecipe.scaledBy(1.5);
      expect(scaled.yield.totalGrams, 1350);
    });

    test('the original recipe is untouched', () {
      cookieRecipe.scaledBy(2);
      expect(cookieRecipe.lines[0].quantity.amount, 250);
      expect(cookieRecipe.yield.count, 24);
    });
  });

  group('role-based scaling exponents', () {
    test('a line without an exponent scales linearly', () {
      const line = RecipeLine(
        Ingredient('flour', gramsPerMl: 0.5),
        Quantity(100, Unit.g),
      );
      expect(line.scaledBy(4).quantity.amount, 400);
    });

    test('an exponent of 1 scales like a linear line', () {
      const line = RecipeLine(
        Ingredient('butter', gramsPerMl: 0.95, scalingExponent: 1.0),
        Quantity(200, Unit.g),
      );
      expect(line.scaledBy(1.2).quantity.amount, closeTo(240, 0.001));
    });

    test('a leavening line scales sub-linearly', () {
      const yeast = Ingredient('yeast', gramsPerMl: 0.6, scalingExponent: 0.7);
      const line = RecipeLine(yeast, Quantity(10, Unit.g));
      expect(line.scaledBy(4).quantity.amount, closeTo(26.39, 0.01));
    });

    test('the rounding step applies after the exponent', () {
      const yeast = Ingredient(
        'yeast',
        gramsPerMl: 0.6,
        scalingExponent: 0.7,
        roundingStep: 0.5,
      );
      const line = RecipeLine(yeast, Quantity(10, Unit.g));
      expect(line.scaledBy(4).quantity.amount, 26.5);
    });
  });
}
