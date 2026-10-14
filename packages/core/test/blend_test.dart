import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  const sugar = Ingredient('sugar');
  const erythritol = Ingredient('erythritol');

  group('SweetenerBlend', () {
    test('totals and sucrose equivalence across the blend', () {
      final blend = SweetenerBlend(
        name: 'half sugar',
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );
      expect(blend.totalGrams, closeTo(200, 1e-12));
      expect(blend.sucroseEquivalentPerGram, closeTo(0.85, 1e-12));
      expect(blend.losesBulk, isFalse);
    });

    test('a much weaker blend loses bulk', () {
      final blend = SweetenerBlend(
        name: 'weak sweet',
        grams: {erythritol: 100},
        sweetnessPerGram: {erythritol: 0.7},
      );
      expect(blend.losesBulk, isTrue);
    });

    test('a blend at or above sugar sweetness does not lose bulk', () {
      final blend = SweetenerBlend(
        name: 'sugar only',
        grams: {sugar: 100},
        sweetnessPerGram: {sugar: 1.0},
      );
      expect(blend.losesBulk, isFalse);
    });

    test('replaceSugar converts a sugar mass into blend grams', () {
      final blend = SweetenerBlend(
        name: 'swap sweet',
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );
      final replacement = blend.replaceSugar(
        const Quantity(85, Unit.g),
        sugarInfo: sugar,
      );
      expect(replacement.unit, Unit.g);
      expect(replacement.amount, closeTo(100, 1e-9));
    });

    test('replaceSugar throws when the sugar mass is unresolvable', () {
      final blend = SweetenerBlend(
        name: 'throwing blend',
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );
      expect(
        () => blend.replaceSugar(
          const Quantity(1, Unit.cup),
          sugarInfo: const Ingredient('sugar'),
        ),
        throwsArgumentError,
      );
    });

    test('empty maps throw', () {
      expect(
        () => SweetenerBlend(name: 'empty', grams: {}, sweetnessPerGram: {}),
        throwsArgumentError,
      );
    });

    test('mismatched key sets throw', () {
      expect(
        () => SweetenerBlend(
          name: 'mismatched',
          grams: {sugar: 100},
          sweetnessPerGram: {erythritol: 0.7},
        ),
        throwsArgumentError,
      );
    });

    test('negative and zero grams throw', () {
      expect(
        () => SweetenerBlend(
          name: 'negative',
          grams: {sugar: -5},
          sweetnessPerGram: {sugar: 1.0},
        ),
        throwsArgumentError,
      );
      expect(
        () => SweetenerBlend(
          name: 'zero',
          grams: {sugar: 0},
          sweetnessPerGram: {sugar: 1.0},
        ),
        throwsArgumentError,
      );
    });
  });

  const breadFlour = Ingredient('bread_flour');
  const cakeFlour = Ingredient('cake_flour');

  group('FlourMix', () {
    test('protein averages weighted by grams', () {
      final mix = FlourMix(
        name: 'half and half',
        grams: {breadFlour: 100, cakeFlour: 100},
        proteinPct: {breadFlour: 12, cakeFlour: 8},
      );
      expect(mix.totalGrams, closeTo(200, 1e-12));
      expect(mix.proteinPct, closeTo(10, 1e-12));
    });

    test('hydration heuristic at 10 percent protein', () {
      final mix = FlourMix(
        name: 'ten protein',
        grams: {breadFlour: 100, cakeFlour: 100},
        proteinPct: {breadFlour: 12, cakeFlour: 8},
      );
      expect(mix.breadHydrationPct(), closeTo(58, 1e-12));
    });

    test('hydration clamps high-protein flours to 85', () {
      final mix = FlourMix(
        name: 'gluten bomb',
        grams: {breadFlour: 100},
        proteinPct: {breadFlour: 20},
      );
      expect(mix.breadHydrationPct(), closeTo(85, 1e-12));
    });

    test('hydration clamps low-protein flours to 55', () {
      final mix = FlourMix(
        name: 'cake flour',
        grams: {cakeFlour: 100},
        proteinPct: {cakeFlour: 5},
      );
      expect(mix.breadHydrationPct(), closeTo(55, 1e-12));
    });

    test('empty maps throw', () {
      expect(
        () => FlourMix(name: 'empty', grams: {}, proteinPct: {}),
        throwsArgumentError,
      );
    });

    test('mismatched key sets throw', () {
      expect(
        () => FlourMix(
          name: 'mismatched',
          grams: {breadFlour: 100},
          proteinPct: {cakeFlour: 12},
        ),
        throwsArgumentError,
      );
    });

    test('negative grams throw', () {
      expect(
        () => FlourMix(
          name: 'negative',
          grams: {breadFlour: -1},
          proteinPct: {breadFlour: 12},
        ),
        throwsArgumentError,
      );
    });
  });

  group('Blend base', () {
    test('name and id travel through the base contract', () {
      final Blend blend = SweetenerBlend(
        name: 'berry mix',
        id: 'berry-1',
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );
      expect(blend.name, 'berry mix');
      expect(blend.id, 'berry-1');
      expect(blend, isA<Blend>());
      expect(blend.totalGrams, closeTo(200, 1e-12));
      expect(blend.grams, {sugar: 100, erythritol: 100});
    });

    test('an ad-hoc blend has a null id', () {
      final Blend blend = SweetenerBlend(
        name: 'ad hoc',
        grams: {sugar: 100},
        sweetnessPerGram: {sugar: 1.0},
      );
      expect(blend.id, isNull);
    });

    test('a flour mix satisfies the same base contract', () {
      final Blend mix = FlourMix(
        name: 'bread mix',
        id: 'bread-1',
        grams: {breadFlour: 100, cakeFlour: 100},
        proteinPct: {breadFlour: 12, cakeFlour: 8},
      );
      expect(mix.name, 'bread mix');
      expect(mix.id, 'bread-1');
      expect(mix.totalGrams, closeTo(200, 1e-12));
      expect(mix.grams, {breadFlour: 100, cakeFlour: 100});
    });

    test('the exposed grams map is unmodifiable', () {
      final Blend blend = SweetenerBlend(
        name: 'locked',
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );
      expect(() => blend.grams[sugar] = 1, throwsUnsupportedError);
      expect(blend.totalGrams, closeTo(200, 1e-12));
    });

    test('the exposed sweetness map is unmodifiable', () {
      final blend = SweetenerBlend(
        name: 'locked sweet',
        grams: {sugar: 100},
        sweetnessPerGram: {sugar: 1.0},
      );
      expect(() => blend.sweetnessPerGram[sugar] = 9, throwsUnsupportedError);
      expect(blend.sucroseEquivalentPerGram, closeTo(1.0, 1e-12));
    });

    test('the exposed protein map is unmodifiable', () {
      final mix = FlourMix(
        name: 'locked flour',
        grams: {breadFlour: 100},
        proteinPct: {breadFlour: 12},
      );
      expect(() => mix.proteinPcts[breadFlour] = 99, throwsUnsupportedError);
      expect(mix.proteinPct, closeTo(12, 1e-12));
    });
  });
}
