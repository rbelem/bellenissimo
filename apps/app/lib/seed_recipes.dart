import 'package:bellenissimos_core/core.dart';

// The seed egg has no rounding step; cookies scale eggs in halves.
final Ingredient _egg = Ingredient(
  'egg',
  gramsPerPiece: seedIngredients['egg']!.gramsPerPiece,
  roundingStep: 0.5,
);

final Recipe butterCookies = Recipe(
  name: 'Butter cookies',
  yield: const YieldSpec(count: 24),
  lines: [
    RecipeLine(seedIngredients['flour']!, const Quantity(250, Unit.g)),
    RecipeLine(seedIngredients['butter']!, const Quantity(200, Unit.g)),
    RecipeLine(seedIngredients['sugar']!, const Quantity(100, Unit.g)),
    RecipeLine(_egg, const Quantity(1, Unit.piece)),
  ],
);

final Recipe sandwichLoaf = Recipe(
  name: 'Sandwich loaf',
  yield: const YieldSpec(totalGrams: 900),
  lines: [
    RecipeLine(seedIngredients['flour']!, const Quantity(500, Unit.g)),
    RecipeLine(seedIngredients['water']!, const Quantity(320, Unit.g)),
    RecipeLine(seedIngredients['salt']!, const Quantity(10, Unit.g)),
  ],
);
