import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  final flour = const Ingredient('flour', gramsPerMl: 0.5);
  final egg = const Ingredient('egg', gramsPerPiece: 50);

  group('ingredient-bridged conversions', () {
    test('cups of flour to grams via density', () {
      final q = const Quantity(2, Unit.cup).convertTo(Unit.g, ingredient: flour);
      expect(q.amount, 240);
    });

    test('grams of water to cups via density', () {
      const water = Ingredient('water', gramsPerMl: 1.0);
      final q = const Quantity(480, Unit.g).convertTo(Unit.cup, ingredient: water);
      expect(q.amount, 2);
    });

    test('eggs to grams via piece weight', () {
      final q = const Quantity(2, Unit.piece).convertTo(Unit.g, ingredient: egg);
      expect(q.amount, 100);
    });

    test('grams to eggs via piece weight', () {
      final q = const Quantity(100, Unit.g).convertTo(Unit.piece, ingredient: egg);
      expect(q.amount, 2);
    });

    test('grams to cups then back is lossless to rounding', () {
      const honey = Ingredient('honey', gramsPerMl: 1.42);
      const start = Quantity(340, Unit.g);
      final roundTrip = start
          .convertTo(Unit.cup, ingredient: honey)
          .convertTo(Unit.g, ingredient: honey);
      expect(roundTrip.amount, closeTo(340, 0.01));
    });

    test('pieces to volume needs density and piece weight', () {
      const dough = Ingredient('dough', gramsPerPiece: 60, gramsPerMl: 0.6);
      final q = const Quantity(2, Unit.piece).convertTo(Unit.ml, ingredient: dough);
      expect(q.amount, 200);
    });

    test('volume to pieces needs density and piece weight', () {
      const dough = Ingredient('dough', gramsPerPiece: 60, gramsPerMl: 0.6);
      final q = const Quantity(200, Unit.ml).convertTo(Unit.piece, ingredient: dough);
      expect(q.amount, 2);
    });

    test('cross-kind without density throws naming the ingredient', () {
      final noDensity = const Ingredient('stevia');
      expect(
        () => const Quantity(1, Unit.cup).convertTo(Unit.g, ingredient: noDensity),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('stevia'),
          ),
        ),
      );
    });

    test('eggs to cups without density throws', () {
      expect(
        () => const Quantity(2, Unit.piece).convertTo(Unit.cup, ingredient: egg),
        throwsArgumentError,
      );
    });
  });

  group('canonical views of a quantity', () {
    test('gramsOf resolves mass directly', () {
      expect(const Quantity(2, Unit.kg).gramsOf(null), 2000);
    });

    test('gramsOf resolves volume through density', () {
      expect(const Quantity(1, Unit.cup).gramsOf(flour), 120);
    });

    test('gramsOf resolves pieces through piece weight', () {
      expect(const Quantity(3, Unit.piece).gramsOf(egg), 150);
    });

    test('gramsOf returns null when data is missing', () {
      expect(const Quantity(1, Unit.cup).gramsOf(null), isNull);
    });

    test('millilitresOf resolves volume directly', () {
      expect(const Quantity(2, Unit.l).millilitresOf(null), 2000);
    });

    test('millilitresOf resolves mass through density', () {
      expect(const Quantity(240, Unit.g).millilitresOf(flour), 480);
    });

    test('millilitresOf resolves pieces through both weights', () {
      const dough = Ingredient('dough', gramsPerPiece: 60, gramsPerMl: 0.6);
      expect(const Quantity(2, Unit.piece).millilitresOf(dough), 200);
    });

    test('millilitresOf returns null when data is missing', () {
      expect(const Quantity(2, Unit.piece).millilitresOf(egg), isNull);
    });
  });
}
