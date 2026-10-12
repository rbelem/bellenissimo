import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  final eggsSnapped =
      const Ingredient('egg', gramsPerPiece: 50, roundingStep: 0.5);

  final crust = Recipe(
    name: 'pie crust',
    yield: const YieldSpec(totalGrams: 300),
    lines: [
      const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(200, Unit.g)),
      const RecipeLine(Ingredient('butter', gramsPerMl: 0.95), Quantity(100, Unit.g)),
    ],
  );

  final sponge = Recipe(
    name: 'sponge',
    yield: const YieldSpec(count: 1),
    lines: [
      const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      RecipeLine(eggsSnapped, const Quantity(1, Unit.piece)),
    ],
  );

  final filling = Recipe(
    name: 'filling',
    yield: const YieldSpec(totalGrams: 200),
    lines: [
      const RecipeLine(Ingredient('cream', gramsPerMl: 1.0), Quantity(200, Unit.g)),
    ],
  );

  final topping = Recipe(
    name: 'ganache',
    yield: const YieldSpec(totalGrams: 150),
    lines: [
      const RecipeLine(Ingredient('chocolate', gramsPerMl: 1.3), Quantity(150, Unit.g)),
    ],
  );

  group('compound recipes', () {
    test('scaling a pie scales the crust ref, its yield, and the leaf line', () {
      final pie = RecipeTree(name: 'apple pie', components: [
        ComponentRef(crust, factor: 1.0),
        const ComponentLeaf(
          RecipeLine(Ingredient('apple', gramsPerMl: 0.6), Quantity(400, Unit.g)),
        ),
      ]);

      final scaled = pie.scaledBy(0.5);

      expect(scaled.name, 'apple pie');
      final ref = scaled.components[0] as ComponentRef;
      expect(ref.factor, 0.5);
      expect(ref.recipe.yield.totalGrams, 150);
      expect(ref.recipe.lines[0].quantity.amount, 100);
      expect(ref.recipe.lines[1].quantity.amount, 50);
      final leaf = scaled.components[1] as ComponentLeaf;
      expect(leaf.line.quantity.amount, 200);
    });

    test('a ref ingredient with a rounding step rounds once, not twice', () {
      final tree = RecipeTree(name: 'torte', components: [
        ComponentRef(sponge, factor: 0.5),
      ]);

      final scaled = tree.scaledBy(1.2);

      final ref = scaled.components.single as ComponentRef;
      expect(ref.factor, 0.6);
      expect(ref.recipe.lines[1].quantity.amount, 0.5);
    });
  });

  group('layered cakes', () {
    test('three layers with topping lay out sponge, filling and topping refs', () {
      final cake = layeredCake(
        sponge: sponge,
        filling: filling,
        topping: topping,
        layers: 3,
        spongeFactorPerLayer: 1.5,
      );

      expect(cake.name, 'layered cake (3 layers)');
      expect(cake.components, hasLength(6));

      for (final i in [0, 1, 2]) {
        final ref = cake.components[i] as ComponentRef;
        expect(ref.recipe, same(sponge));
        expect(ref.factor, 1.5);
      }
      expect((cake.components[3] as ComponentRef).recipe, same(filling));
      expect((cake.components[3] as ComponentRef).factor, 1.0);
      expect((cake.components[4] as ComponentRef).recipe, same(filling));
      expect((cake.components[4] as ComponentRef).factor, 1.0);
      expect((cake.components[5] as ComponentRef).recipe, same(topping));
      expect((cake.components[5] as ComponentRef).factor, 1.0);
    });

    test('one sponge ref yields base contents scaled by exactly the factor', () {
      final cake = layeredCake(
        sponge: sponge,
        filling: filling,
        layers: 2,
        spongeFactorPerLayer: 1.5,
      );

      final ref = cake.components.first as ComponentRef;
      final effective = ref.recipe.scaledBy(ref.factor);
      expect(effective.lines[0].quantity.amount, 375);
      expect(effective.lines[1].quantity.amount, 1.5);
      expect(ref.recipe.lines[0].quantity.amount, 250);
    });

    test('a cake without topping has no topping ref', () {
      final cake = layeredCake(
        sponge: sponge,
        filling: filling,
        layers: 2,
        spongeFactorPerLayer: 1.0,
      );

      expect(cake.components, hasLength(3));
      expect(
        cake.components
            .every((c) => (c as ComponentRef).recipe.name != 'ganache'),
        isTrue,
      );
    });

    test('one layer is not a layered cake', () {
      expect(
        () => layeredCake(
          sponge: sponge,
          filling: filling,
          layers: 1,
          spongeFactorPerLayer: 1.0,
        ),
        throwsArgumentError,
      );
    });

    test('scaling a layered cake multiplies every ref factor', () {
      final cake = layeredCake(
        sponge: sponge,
        filling: filling,
        topping: topping,
        layers: 3,
        spongeFactorPerLayer: 1.5,
      );

      final half = cake.scaledBy(0.5);

      expect((half.components[0] as ComponentRef).factor, 0.75);
      expect((half.components[2] as ComponentRef).factor, 0.75);
      expect((half.components[3] as ComponentRef).factor, 0.5);
      expect((half.components[5] as ComponentRef).factor, 0.5);
      final eggRef = half.components[0] as ComponentRef;
      expect(eggRef.recipe.lines[1].quantity.amount, 1.0);
    });
  });
}
