import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
