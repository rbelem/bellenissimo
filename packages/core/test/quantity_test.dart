import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  group('Quantity conversions within one kind', () {
    test('grams to kilograms', () {
      final q = const Quantity(500, Unit.g).convertTo(Unit.kg);
      expect(q.amount, 0.5);
      expect(q.unit, Unit.kg);
    });

    test('cups to millilitres uses 240 ml per cup', () {
      final q = const Quantity(2, Unit.cup).convertTo(Unit.ml);
      expect(q.amount, 480);
    });

    test('pounds to grams', () {
      final q = const Quantity(1, Unit.lb).convertTo(Unit.g);
      expect(q.amount, closeTo(453.592, 0.001));
    });

    test('converting to the same unit returns the same quantity', () {
      const q = Quantity(3, Unit.tbsp);
      expect(q.convertTo(Unit.tbsp), same(q));
    });

    test('litres to fluid ounces', () {
      final q = const Quantity(1, Unit.l).convertTo(Unit.flOz);
      expect(q.amount, closeTo(33.814, 0.01));
    });
  });

  group('Quantity conversions across kinds', () {
    test('mass to volume without an ingredient throws', () {
      expect(
        () => const Quantity(100, Unit.g).convertTo(Unit.cup),
        throwsArgumentError,
      );
    });

    test('volume to mass without an ingredient throws', () {
      expect(
        () => const Quantity(1, Unit.cup).convertTo(Unit.g),
        throwsArgumentError,
      );
    });
  });

  group('Quantity scaling and rounding', () {
    test('scaledBy multiplies the amount', () {
      final q = const Quantity(200, Unit.g).scaledBy(1.5);
      expect(q.amount, 300);
      expect(q.unit, Unit.g);
    });

    test('roundedToNearest snaps to the given step', () {
      final q = const Quantity(2.37, Unit.piece).roundedToNearest(0.5);
      expect(q.amount, 2.5);
      expect(q.unit, Unit.piece);
    });

    test('roundedToNearest rounds half away from zero', () {
      final q = const Quantity(1.25, Unit.piece).roundedToNearest(0.5);
      expect(q.amount, 1.5);
    });
  });
}
