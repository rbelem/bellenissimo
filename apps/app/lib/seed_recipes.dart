import 'package:bellenissimos_core/core.dart';

// The seed egg has no rounding step; cookies scale eggs in halves.
final Ingredient _egg = Ingredient(
  'egg',
  gramsPerPiece: seedIngredients['egg']!.gramsPerPiece,
  roundingStep: 0.5,
);

final Recipe butterCookies = Recipe(
  id: 'butter-cookies',
  name: 'Butter cookies',
  yield: const YieldSpec(count: 24),
  lines: [
    RecipeLine(seedIngredients['flour']!, const Quantity(250, Unit.g)),
    RecipeLine(seedIngredients['butter']!, const Quantity(200, Unit.g)),
    RecipeLine(seedIngredients['sugar']!, const Quantity(100, Unit.g)),
    RecipeLine(_egg, const Quantity(1, Unit.piece)),
  ],
  steps: const [
    'cream the butter and sugar',
    'beat in the egg',
    'fold in the flour',
    'scoop 24 cookies onto a tray and bake at 180 C for 12 minutes',
  ],
  createdAt: DateTime(2026, 1, 15, 10, 30),
  updatedAt: DateTime(2026, 1, 20, 18, 45),
);

final Recipe sandwichLoaf = Recipe(
  id: 'sandwich-loaf',
  name: 'Sandwich loaf',
  yield: const YieldSpec(totalGrams: 900),
  lines: [
    RecipeLine(seedIngredients['flour']!, const Quantity(500, Unit.g)),
    RecipeLine(seedIngredients['water']!, const Quantity(320, Unit.g)),
    RecipeLine(seedIngredients['salt']!, const Quantity(10, Unit.g)),
  ],
  steps: const [
    'mix the flour, water and salt into a shaggy dough',
    'knead until smooth, about 10 minutes',
    'let rise until doubled, about 1 hour',
    'shape, proof 45 minutes, then bake at 220 C for 35 minutes',
  ],
  createdAt: DateTime(2026, 1, 16, 8, 0),
  updatedAt: DateTime(2026, 1, 16, 8, 0),
);

final Recipe eggFreeCookies = butterCookies.copyWith(
  id: 'egg-free-cookies',
  parentId: 'butter-cookies',
  name: 'Egg-free butter cookies',
  lines: [
    RecipeLine(seedIngredients['flour']!, const Quantity(250, Unit.g)),
    RecipeLine(seedIngredients['butter']!, const Quantity(200, Unit.g)),
    RecipeLine(seedIngredients['sugar']!, const Quantity(100, Unit.g)),
    RecipeLine(const Ingredient('applesauce'), const Quantity(120, Unit.g)),
  ],
  steps: const [
    'cream the butter and sugar',
    'beat in the applesauce',
    'fold in the flour',
    'scoop 24 cookies and bake at 170 C for 14 minutes',
  ],
  createdAt: DateTime(2026, 2, 1, 14, 0),
  updatedAt: DateTime(2026, 2, 3, 9, 30),
);
