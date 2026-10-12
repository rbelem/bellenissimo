import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Quantity value semantics', () {
    test('equal amounts in equal units are equal', () {
      expect(const Quantity(200, Unit.g), const Quantity(200, Unit.g));
    });

    test('equal quantities share a hash code', () {
      expect(
        const Quantity(200, Unit.g).hashCode,
        const Quantity(200, Unit.g).hashCode,
      );
    });

    test('different amounts are not equal', () {
      expect(const Quantity(200, Unit.g), isNot(const Quantity(300, Unit.g)));
    });

    test('same amount in different units is not equal', () {
      expect(const Quantity(1, Unit.kg), isNot(const Quantity(1, Unit.g)));
    });

    test('a quantity is not equal to another type', () {
      expect(const Quantity(1, Unit.g), isNot(equals('1 g')));
    });

    test('toString renders integral amounts without decimals', () {
      expect(const Quantity(250, Unit.g).toString(), '250 g');
    });

    test('toString keeps decimals for fractional amounts', () {
      expect(const Quantity(1.5, Unit.piece).toString(), '1.5 piece');
    });
  });

  group('Ingredient identity semantics', () {
    test('ingredients with the same id are equal', () {
      expect(
        const Ingredient('flour', gramsPerMl: 0.5),
        const Ingredient('flour', gramsPerMl: 0.55),
      );
    });

    test('ingredients with different ids are not equal', () {
      expect(
        const Ingredient('flour'),
        isNot(const Ingredient('sugar')),
      );
    });

    test('hash codes follow id equality', () {
      expect(
        const Ingredient('flour').hashCode,
        const Ingredient('flour').hashCode,
      );
    });

    test('toString returns the id', () {
      expect(const Ingredient('brown_sugar').toString(), 'brown_sugar');
    });
  });
}
