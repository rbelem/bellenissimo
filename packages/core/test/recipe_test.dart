import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  final eggsSnapped = const Ingredient('egg', gramsPerPiece: 50, roundingStep: 0.5);

  final cookieRecipe = Recipe(
    name: 'butter cookies',
    yield: const YieldSpec(count: 24),
    items: [
      const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      const RecipeLine(Ingredient('butter', gramsPerMl: 0.95), Quantity(200, Unit.g)),
      RecipeLine(eggsSnapped, const Quantity(1, Unit.piece)),
    ],
  );

  final breadRecipe = Recipe(
    name: 'sandwich loaf',
    yield: const YieldSpec(totalGrams: 900),
    items: [
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
      expect((scaled.items[0] as RecipeLine).quantity.amount, 375);
      expect((scaled.items[1] as RecipeLine).quantity.amount, 300);
    });

    test('eggs snap to half eggs when the ingredient declares a step', () {
      final scaled = cookieRecipe.scaledBy(1.25);
      expect((scaled.items[2] as RecipeLine).quantity.amount, 1.5);
    });

    test('ingredients without a rounding step stay exact', () {
      final scaled = breadRecipe.scaledBy(1.1);
      expect((scaled.items[0] as RecipeLine).quantity.amount, closeTo(550, 0.001));
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
      expect((cookieRecipe.items[0] as RecipeLine).quantity.amount, 250);
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

  group('compound recipes', () {
    final batter = Recipe(
      id: 'batter',
      name: 'batter',
      yield: const YieldSpec(count: 1),
      items: [
        const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
        RecipeLine(eggsSnapped, const Quantity(1, Unit.piece)),
      ],
    );

    test('a compound recipe holds its tree components as items and isCompound', () {
      final created = DateTime(2026, 10, 14);
      final cake = Recipe.compound(
        id: 'cake',
        name: 'layer cake',
        yield: const YieldSpec(count: 1, totalGrams: 800),
        tree: RecipeTree(name: 'layer cake', components: [
          ComponentRef(batter, factor: 2.0),
        ]),
        steps: const ['bake', 'stack'],
        createdAt: created,
        updatedAt: created,
      );

      expect(cake.isCompound, isTrue);
      expect(cake.id, 'cake');
      expect(cake.steps, ['bake', 'stack']);
      expect(cake.createdAt, created);
      expect(cake.updatedAt, created);
      expect(cake.items.single, isA<ComponentRef>());
      expect((cake.items.single as ComponentRef).recipe, same(batter));
    });

    test('a plain recipe is not compound', () {
      expect(cookieRecipe.isCompound, isFalse);
    });

    test('scaling a compound scales yield, accumulates ref factors and snaps a part exactly once', () {
      final cake = Recipe.compound(
        name: 'layer cake',
        yield: const YieldSpec(count: 1, totalGrams: 800),
        tree: RecipeTree(name: 'layer cake', components: [
          ComponentRef(batter, factor: 1.0),
        ]),
      );

      final small = cake.scaledBy(0.6);

      expect(small.yield.count, closeTo(0.6, 1e-9));
      expect(small.yield.totalGrams, closeTo(480, 1e-9));
      final ref = small.items.single as ComponentRef;
      expect(ref.factor, closeTo(0.6, 1e-9));
      expect(ref.recipe, same(batter));
      final effective = ref.recipe.scaledBy(ref.factor);
      expect((effective.items[0] as RecipeLine).quantity.amount, closeTo(150, 1e-9));
      expect((effective.items[1] as RecipeLine).quantity.amount, 0.5);
    });

    test('scaling a compound scales leaf components too', () {
      final cake = Recipe.compound(
        name: 'torte',
        yield: const YieldSpec(totalGrams: 900),
        tree: RecipeTree(name: 'torte', components: [
          const RecipeLine(Ingredient('sugar', gramsPerMl: 0.85), Quantity(100, Unit.g)),
        ]),
      );

      final scaled = cake.scaledBy(2);

      final leaf = scaled.items.single as RecipeLine;
      expect(leaf.quantity.amount, 200);
    });
  });

  group('Recipe.replaceRecipe', () {
    final batterA = Recipe(
      id: 'batter-a',
      name: 'batter a',
      yield: const YieldSpec(count: 1),
      items: [
        const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      ],
    );

    final batterB = Recipe(
      id: 'batter-b',
      parentId: 'batter-a',
      name: 'batter b',
      yield: const YieldSpec(count: 1),
      items: [
        const RecipeLine(Ingredient('spelt', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      ],
    );

    test('a recipe with no matching item returns this identically', () {
      expect(
        identical(cookieRecipe.replaceRecipe('batter-a', batterB), cookieRecipe),
        isTrue,
      );
    });

    test('items without a matching ref return this identically', () {
      final cake = Recipe.compound(
        name: 'layer cake',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(name: 'layer cake', components: [
          ComponentRef(batterA, factor: 1.0),
        ]),
      );

      expect(identical(cake.replaceRecipe('nope', batterB), cake), isTrue);
    });

    test('a swap on a scaled compound keeps the accumulated factor and the magnitude', () {
      final cake = Recipe.compound(
        name: 'layer cake',
        yield: const YieldSpec(count: 2),
        tree: RecipeTree(name: 'layer cake', components: [
          ComponentRef(batterA, factor: 1.0),
        ]),
      );
      final derivative = cake.scaledBy(2);

      final swapped = derivative.replaceRecipe('batter-a', batterB);

      expect(identical(swapped, derivative), isFalse);
      final ref = swapped.items.single as ComponentRef;
      expect(ref.factor, closeTo(2.0, 1e-9));
      expect(ref.recipe, same(batterB));
      expect((batterA.scaledBy(2).items.single as RecipeLine).quantity.amount,
          (batterB.scaledBy(ref.factor).items.single as RecipeLine).quantity.amount);
    });
  });

  group('RecipeBook.replacingRecipe', () {
    final batterA = Recipe(
      id: 'batter-a',
      name: 'batter a',
      yield: const YieldSpec(count: 1),
      items: [
        const RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      ],
    );

    final batterB = Recipe(
      id: 'batter-b',
      parentId: 'batter-a',
      name: 'batter b',
      yield: const YieldSpec(count: 1),
      items: [
        const RecipeLine(Ingredient('spelt', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      ],
    );

    test('the walk reuses non-holders by identity and preserves timestamps on the holder', () {
      final created = DateTime(2026, 10, 14, 9);
      final updated = DateTime(2026, 10, 14, 10);
      final plain = Recipe(
        id: 'cookies',
        name: 'cookies',
        yield: const YieldSpec(count: 24),
        items: const [
          RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
        ],
      );
      final cake = Recipe.compound(
        id: 'cake',
        name: 'layer cake',
        yield: const YieldSpec(count: 2),
        tree: RecipeTree(name: 'layer cake', components: [
          ComponentRef(batterA, factor: 1.5),
        ]),
        createdAt: created,
        updatedAt: updated,
      );
      final book = RecipeBook([plain, cake]);

      final replaced = book.replacingRecipe('batter-a', batterB);

      expect(identical(replaced.recipes[0], plain), isTrue);
      expect(identical(replaced.recipes[1], cake), isFalse);
      expect(replaced.recipes[1].createdAt, created);
      expect(replaced.recipes[1].updatedAt, updated);
      final ref = replaced.recipes[1].items.single as ComponentRef;
      expect(ref.factor, 1.5);
      expect(ref.recipe, same(batterB));
    });
  });

  group('unified items', () {
    const sugar = Ingredient('sugar');
    final berry = SweetenerBlend(
      name: 'berry mix',
      id: 'berry-1',
      grams: {sugar: 100},
      sweetnessPerGram: {sugar: 0.7},
    );
    final batter = Recipe(
      id: 'batter',
      name: 'batter',
      yield: const YieldSpec(count: 1),
      items: const [
        RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(250, Unit.g)),
      ],
    );

    test('items keep their kinds and order through scaling', () {
      final dish = Recipe(
        name: 'dish',
        yield: const YieldSpec(count: 1),
        items: [
          const RecipeLine(
            Ingredient('flour', gramsPerMl: 0.5),
            Quantity(100, Unit.g),
          ),
          BlendLine(berry, 10),
          ComponentRef(batter, factor: 2.0),
        ],
      );

      final scaled = dish.scaledBy(3);

      expect(scaled.items, hasLength(3));
      expect(
        (scaled.items[0] as RecipeLine).quantity.amount,
        closeTo(300, 1e-9),
      );
      expect((scaled.items[1] as BlendLine).grams, closeTo(30, 1e-9));
      final ref = scaled.items[2] as ComponentRef;
      expect(ref.factor, closeTo(6.0, 1e-9));
      expect(ref.recipe, same(batter));
    });

    test('a recipe holding a ref is compound', () {
      final dish = Recipe(
        name: 'dish',
        yield: const YieldSpec(count: 1),
        items: [ComponentRef(batter, factor: 1.0)],
      );
      expect(dish.isCompound, isTrue);
    });

    test('a blend use inside a tree scales exactly', () {
      final cake = Recipe.compound(
        name: 'cake',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(name: 'cake', components: [BlendLine(berry, 40)]),
      );

      final scaled = cake.scaledBy(2.5);

      expect((scaled.items.single as BlendLine).grams, closeTo(100, 1e-9));
    });

    test('replaceBlend and replaceRecipe both walk one items list', () {
      final replacementBlend = SweetenerBlend(
        name: 'new berry',
        id: 'berry-1',
        grams: {sugar: 100},
        sweetnessPerGram: {sugar: 0.7},
      );
      final replacementBatter = Recipe(
        id: 'batter',
        name: 'new batter',
        yield: const YieldSpec(count: 1),
        items: const [
          RecipeLine(
            Ingredient('spelt', gramsPerMl: 0.5),
            Quantity(250, Unit.g),
          ),
        ],
      );
      final dish = Recipe(
        id: 'dish',
        name: 'dish',
        yield: const YieldSpec(count: 1),
        items: [
          const RecipeLine(
            Ingredient('flour', gramsPerMl: 0.5),
            Quantity(100, Unit.g),
          ),
          BlendLine(berry, 10),
          ComponentRef(batter, factor: 2.0),
        ],
      );

      final swapped = dish
          .replaceBlend('berry-1', replacementBlend)
          .replaceRecipe('batter', replacementBatter);

      expect(swapped.items[0], same(dish.items[0]));
      expect(
        (swapped.items[1] as BlendLine).blend,
        same(replacementBlend),
      );
      expect((swapped.items[1] as BlendLine).grams, 10);
      final ref = swapped.items[2] as ComponentRef;
      expect(ref.recipe, same(replacementBatter));
      expect(ref.factor, 2.0);
    });
  });

  group('nested compounds', () {    test('a compound ref that is itself a compound scales by the factor product', () {
      final cream = Recipe(
        name: 'cream',
        yield: const YieldSpec(count: 1),
        items: [
          const RecipeLine(Ingredient('cream', gramsPerMl: 1.0), Quantity(10, Unit.g)),
        ],
      );
      final inner = Recipe.compound(
        name: 'filling stack',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(name: 'filling stack', components: [
          ComponentRef(cream, factor: 2.0),
        ]),
      );
      final outer = Recipe.compound(
        name: 'giant torte',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(name: 'giant torte', components: [
          ComponentRef(inner, factor: 3.0),
        ]),
      );

      final scaled = outer.scaledBy(5);

      final outerRef = scaled.items.single as ComponentRef;
      expect(outerRef.factor, closeTo(15.0, 1e-9));
      expect(outerRef.recipe, same(inner));
      final effective = outerRef.recipe.scaledBy(outerRef.factor);
      final innerRef = effective.items.single as ComponentRef;
      expect(innerRef.factor, closeTo(30.0, 1e-9));
      expect(innerRef.recipe, same(cream));
      expect((innerRef.recipe.scaledBy(innerRef.factor).items.single as RecipeLine).quantity.amount,
          closeTo(300, 1e-9));
    });
  });
}
