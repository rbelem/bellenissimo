import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _batter() => Recipe(
  id: 'batter',
  name: 'Batter',
  yield: const YieldSpec(count: 1),
  lines: [
    RecipeLine(
      const Ingredient('flour', gramsPerMl: 0.6),
      const Quantity(500, Unit.g),
    ),
  ],
);

Recipe _compound() => Recipe.compound(
  id: 'cake',
  name: 'Cake',
  parentId: 'tarts',
  yield: const YieldSpec(count: 1),
  steps: const ['stack'],
  createdAt: DateTime(2026, 5, 1),
  updatedAt: DateTime(2026, 5, 2),
  tree: RecipeTree(
    name: 'assembled cake',
    components: [
      ComponentRef(_batter(), factor: 2),
      ComponentLeaf(
        RecipeLine(const Ingredient('salt'), const Quantity(5, Unit.g)),
      ),
    ],
  ),
);

void main() {
  test('codec roundtrip preserves the scaling exponent', () {
    final yeast = const Ingredient(
      'yeast',
      gramsPerMl: 0.6,
      scalingExponent: 0.7,
    );
    final recipe = Recipe(
      id: 'levain',
      name: 'Levain',
      yield: const YieldSpec(count: 1),
      lines: [RecipeLine(yeast, const Quantity(7, Unit.g))],
    );

    final restored = RecipeCodec.decode(RecipeCodec.encode(recipe));

    expect(restored.lines.single.ingredient.scalingExponent, 0.7);
    expect(restored.lines.single.ingredient.gramsPerMl, 0.6);
  });

  test('codec roundtrip keeps a linear ingredient exponent-free', () {
    final flour = const Ingredient('flour', gramsPerMl: 0.6);
    final recipe = Recipe(
      id: 'flat',
      name: 'Flat',
      yield: const YieldSpec(count: 1),
      lines: [RecipeLine(flour, const Quantity(500, Unit.g))],
    );

    final restored = RecipeCodec.decode(RecipeCodec.encode(recipe));

    expect(restored.lines.single.ingredient.scalingExponent, isNull);
  });

  test('codec roundtrips a compound with a ref and a leaf', () {
    final restored = RecipeCodec.decode(RecipeCodec.encode(_compound()));

    expect(restored.isCompound, isTrue);
    expect(restored.lines, isEmpty);
    expect(restored.blends, isEmpty);
    final tree = restored.tree!;
    expect(tree.name, 'assembled cake');
    final ref = tree.components[0] as ComponentRef;
    expect(ref.factor, 2);
    expect(ref.recipe.id, 'batter');
    expect(ref.recipe.lines.single.ingredient.id, 'flour');
    expect(ref.recipe.lines.single.ingredient.gramsPerMl, 0.6);
    expect(ref.recipe.lines.single.quantity.amount, 500);
    final leaf = tree.components[1] as ComponentLeaf;
    expect(leaf.line.ingredient.id, 'salt');
    expect(leaf.line.quantity.amount, 5);
  });

  test('codec roundtrips a nested compound ref', () {
    final tart = Recipe.compound(
      id: 'tart',
      name: 'Tart',
      yield: const YieldSpec(count: 1),
      tree: RecipeTree(
        name: 'tart shell',
        components: [
          ComponentLeaf(
            RecipeLine(const Ingredient('butter'), const Quantity(120, Unit.g)),
          ),
        ],
      ),
    );
    final outer = Recipe.compound(
      id: 'pie',
      name: 'Pie',
      yield: const YieldSpec(count: 1),
      tree: RecipeTree(
        name: 'pie',
        components: [ComponentRef(tart, factor: 1.5)],
      ),
    );

    final restored = RecipeCodec.decode(RecipeCodec.encode(outer));

    final ref = restored.tree!.components.single as ComponentRef;
    expect(ref.factor, 1.5);
    expect(ref.recipe.isCompound, isTrue);
    expect(
      (ref.recipe.tree!.components.single as ComponentLeaf)
          .line
          .ingredient
          .id,
      'butter',
    );
  });

  test('codec preserves compound id, lineage, steps and timestamps', () {
    final restored = RecipeCodec.decode(RecipeCodec.encode(_compound()));

    expect(restored.id, 'cake');
    expect(restored.parentId, 'tarts');
    expect(restored.steps, ['stack']);
    expect(restored.createdAt, DateTime(2026, 5, 1));
    expect(restored.updatedAt, DateTime(2026, 5, 2));
    expect(restored.yield.count, 1);
  });

  test('a doc carrying a tree and lines is rejected at decode', () {
    final doc = RecipeCodec.encode(_compound());
    final batterLines = RecipeCodec.encode(_batter())['lines']! as List<Object?>;
    doc['lines'] = [batterLines.first];

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });

  test('a doc carrying a tree and blends is rejected at decode', () {
    final doc = RecipeCodec.encode(_compound());
    final blend = SweetenerBlend(
      name: 'mix',
      grams: {const Ingredient('honey'): 60},
      sweetnessPerGram: {const Ingredient('honey'): 1.1},
    );
    doc['blends'] = [BlendCodec.encodeLine(BlendLine(blend, 100))];

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });

  test('a tree component that is neither leaf nor ref is rejected', () {
    final doc = RecipeCodec.encode(_compound());
    (doc['tree']! as Map<String, Object?>)['components'] = [
      {'name': 'junk'},
    ];

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });
}
