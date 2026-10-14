import 'dart:convert';

import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  RecipeImportResult importDoc(Map<String, Object?> recipe) =>
      importRecipeJson(jsonEncode({'@type': 'Recipe', ...recipe}));

  group('ingredient line parsing', () {
    test('integer amount with mass unit and seed ingredient', () {
      final result = importDoc({
        'name': 'Bread',
        'recipeYield': '1 loaf',
        'recipeIngredient': ['200 g flour'],
      });
      expect(result.ok, isTrue);
      final line = result.recipe!.lines.single;
      expect(line.quantity.amount, 200);
      expect(line.quantity.unit, Unit.g);
      expect(line.ingredient, seedIngredients['flour']);
      expect(line.ingredient.gramsPerMl, 0.5);
    });

    test('volume unit and seed lookup', () {
      final result = importDoc({
        'name': 'Cake',
        'recipeYield': '1 cake',
        'recipeIngredient': ['1 cup sugar'],
      });
      final line = result.recipe!.lines.single;
      expect(line.quantity, const Quantity(1, Unit.cup));
      expect(line.ingredient.gramsPerMl, 0.83);
    });

    test('no unit word means pieces', () {
      final result = importDoc({
        'name': 'Omelette',
        'recipeYield': '1 serving',
        'recipeIngredient': ['2 eggs'],
      });
      final line = result.recipe!.lines.single;
      expect(line.quantity, const Quantity(2, Unit.piece));
      expect(line.ingredient.id, 'eggs');
      expect(line.ingredient.gramsPerPiece, isNull);
    });

    test('mixed unicode vulgar fraction', () {
      final result = importDoc({
        'name': 'Cookies',
        'recipeYield': '24 cookies',
        'recipeIngredient': ['1½ tsp vanilla'],
      });
      final line = result.recipe!.lines.single;
      expect(line.quantity, const Quantity(1.5, Unit.tsp));
      expect(line.ingredient.id, 'vanilla');
    });

    test('standalone unicode vulgar fraction', () {
      final result = importDoc({
        'name': 'Porridge',
        'recipeYield': '1 bowl',
        'recipeIngredient': ['½ cup milk'],
      });
      expect(result.recipe!.lines.single.quantity, const Quantity(0.5, Unit.cup));
    });

    test('decimal amount with kg and seed ingredient', () {
      final result = importDoc({
        'name': 'Shortbread',
        'recipeYield': '24 pieces',
        'recipeIngredient': ['0.5 kg butter'],
      });
      expect(result.recipe!.lines.single.quantity, const Quantity(0.5, Unit.kg));
      expect(result.recipe!.lines.single.ingredient.gramsPerMl, 0.95);
    });

    test('dash range takes the first value', () {
      final result = importDoc({
        'name': 'Granola',
        'recipeYield': '6 servings',
        'recipeIngredient': ['2-3 cups oats'],
      });
      final line = result.recipe!.lines.single;
      expect(line.quantity, const Quantity(2, Unit.cup));
      expect(line.ingredient.id, 'oats');
    });

    test('"to" range takes the first value', () {
      final result = importDoc({
        'name': 'Salad',
        'recipeYield': '2 bowls',
        'recipeIngredient': ['1 to 2 cups oats'],
      });
      expect(result.recipe!.lines.single.quantity, const Quantity(1, Unit.cup));
    });

    test('two-word unit alias', () {
      final result = importDoc({
        'name': 'Syrup',
        'recipeYield': '1 bottle',
        'recipeIngredient': ['1 fl oz milk'],
      });
      expect(result.recipe!.lines.single.quantity, const Quantity(1, Unit.flOz));
      expect(result.recipe!.lines.single.ingredient.gramsPerMl, 1.02);
    });

    test('unknown unit skips the line with an issue', () {
      final result = importDoc({
        'name': 'Soup',
        'recipeYield': '4 bowls',
        'recipeIngredient': ['1 pinch salt'],
      });
      expect(result.ok, isFalse);
      expect(result.recipe, isNull);
      expect(result.issues, hasLength(1));
      expect(result.issues.single.message, contains('pinch'));
    });

    test('missing amount skips the line with an issue', () {
      final result = importDoc({
        'name': 'Chips',
        'recipeYield': '4 servings',
        'recipeIngredient': ['salt to taste'],
      });
      expect(result.ok, isFalse);
      expect(result.issues.single.message, contains('salt to taste'));
    });

    test('unknown ingredient gets a plain Ingredient with derived id', () {
      final result = importDoc({
        'name': 'Exotic',
        'recipeYield': '2 servings',
        'recipeIngredient': ['300 g dinosaur fruit'],
      });
      final line = result.recipe!.lines.single;
      expect(line.ingredient.id, 'dinosaur_fruit');
      expect(line.ingredient.gramsPerMl, isNull);
      expect(line.quantity, const Quantity(300, Unit.g));
    });
  });

  group('document location', () {
    test('finds the first Recipe node inside a top-level @graph', () {
      final result = importRecipeJson(jsonEncode({
        '@context': 'https://schema.org',
        '@graph': [
          {
            '@type': 'WebPage',
            'name': 'Baking blog',
          },
          {
            '@type': 'Recipe',
            'name': 'Choc Chip Cookies',
            'recipeIngredient': ['200 g flour', '2 eggs'],
          },
        ],
      }));
      expect(result.ok, isTrue);
      expect(result.recipe!.name, 'Choc Chip Cookies');
      expect(result.recipe!.lines, hasLength(2));
    });

    test('matches "@type" given as a list', () {
      final result = importRecipeJson(jsonEncode({
        '@type': ['Recipe'],
        'name': 'Pancakes',
        'recipeIngredient': ['1 l milk'],
      }));
      expect(result.ok, isTrue);
      expect(result.recipe!.lines.single.ingredient.id, 'milk');
    });

    test('matches "@type" case-insensitively', () {
      final result = importRecipeJson(jsonEncode({
        '@type': 'recipe',
        'name': 'Stew',
        'recipeIngredient': ['2 carrots'],
      }));
      expect(result.ok, isTrue);
    });

    test('falls back to any map with a recipeIngredient key', () {
      final result = importRecipeJson(jsonEncode({
        '@type': 'Article',
        'name': 'Not a recipe type',
        'recipeIngredient': ['2 eggs'],
      }));
      expect(result.ok, isTrue);
      expect(result.recipe!.name, 'Not a recipe type');
    });

    test('fallback searches nested maps and lists', () {
      final result = importRecipeJson(jsonEncode({
        'meta': {
          'sections': [
            {
              'name': 'Nested stew',
              'recipeIngredient': ['2 eggs'],
            },
          ],
        },
      }));
      expect(result.ok, isTrue);
      expect(result.recipe!.name, 'Nested stew');
    });

    test('top-level JSON array containing a recipe map', () {
      final result = importRecipeJson(jsonEncode([
        {'name': 'plain map, no recipe'},
        {
          '@type': 'Recipe',
          'name': 'Array stew',
          'recipeIngredient': ['2 eggs'],
        },
      ]));
      expect(result.ok, isTrue);
      expect(result.recipe!.name, 'Array stew');
    });

    test('malformed JSON becomes an issue, never a throw', () {
      final result = importRecipeJson('{not json');
      expect(result.ok, isFalse);
      expect(result.recipe, isNull);
      expect(result.issues.single.message, contains('JSON'));
      expect(result.issues.single.toString(), contains('JSON'));
    });

    test('documents without a recipe produce one issue', () {
      for (final source in [
        '[]',
        '{}',
        '[{"name": "nope"}]',
        '"just a string"',
        jsonEncode({'@graph': [{'@type': 'Person'}]}),
        '42',
      ]) {
        final result = importRecipeJson(source);
        expect(result.recipe, isNull, reason: source);
        expect(result.issues.single.message, contains('No schema.org'),
            reason: source);
      }
    });
  });

  group('yield parsing', () {
    test('count yield', () {
      final result = importDoc({
        'name': 'Cookies',
        'recipeYield': '24 cookies',
        'recipeIngredient': ['2 eggs'],
      });
      expect(result.recipe!.yield.count, 24);
      expect(result.recipe!.yield.totalGrams, isNull);
    });

    test('mass yield with space converts to grams', () {
      final result = importDoc({
        'name': 'Dough',
        'recipeYield': '900 g',
        'recipeIngredient': ['2 eggs'],
      });
      expect(result.recipe!.yield.totalGrams, 900);
      expect(result.recipe!.yield.count, isNull);
    });

    test('merged mass yield with trailing product name', () {
      final result = importDoc({
        'name': 'Dough',
        'recipeYield': '900g dough',
        'recipeIngredient': ['2 eggs'],
      });
      expect(result.recipe!.yield.totalGrams, 900);
    });

    test('kilogram yield converts to grams', () {
      final result = importDoc({
        'name': 'Dough',
        'recipeYield': '1.5 kg dough',
        'recipeIngredient': ['2 eggs'],
      });
      expect(result.recipe!.yield.totalGrams, 1500);
    });

    test('unparseable yield becomes an issue, recipe still imports', () {
      final result = importDoc({
        'name': 'Mystery',
        'recipeYield': 'a lot of cookies',
        'recipeIngredient': ['2 eggs'],
      });
      expect(result.ok, isTrue);
      expect(result.recipe!.yield.count, isNull);
      expect(result.recipe!.yield.totalGrams, isNull);
      expect(result.issues.single.message, contains('recipeYield'));
    });

    test('missing, blank, non-string, and word-suffixed yields all issue', () {
      for (final badYield in [null, '   ', 42, 'big cookies']) {
        final recipe = {
          'name': 'Mystery',
          'recipeIngredient': ['2 eggs'],
          'recipeYield': ?badYield,
        };
        final result = importDoc(recipe);
        expect(result.ok, isTrue, reason: '$badYield');
        expect(result.issues.single.message, contains('recipeYield'),
            reason: '$badYield');
      }
    });
  });

  group('recipe assembly', () {
    test('full valid JSON-LD document end to end', () {
      final result = importRecipeJson(jsonEncode({
        '@context': 'https://schema.org',
        '@graph': [
          {
            '@type': 'Recipe',
            'name': 'Choc Chip Cookies',
            'recipeYield': '24 cookies',
            'recipeInstructions': [
              'Mix everything.',
              'Bake for 12 minutes.',
            ],
            'recipeIngredient': [
              '200 g flour',
              '1 cup sugar',
              '2 eggs',
              '1½ tsp vanilla',
            ],
          },
        ],
      }));
      expect(result.ok, isTrue);
      expect(result.recipe!.name, 'Choc Chip Cookies');
      expect(result.recipe!.yield.count, 24);
      expect(result.recipe!.lines, hasLength(4));
      expect(result.issues, isEmpty);
    });

    test('missing name blocks the recipe', () {
      for (final badName in [null, '', '   ', 42]) {
        final recipe = {
          'recipeYield': '24 cookies',
          'recipeIngredient': ['2 eggs'],
          'name': ?badName,
        };
        final result = importDoc(recipe);
        expect(result.recipe, isNull, reason: '$badName');
        expect(result.issues.any((i) => i.message.contains('name')), isTrue,
            reason: '$badName');
      }
    });

    test('recipeIngredient that is not a list blocks the recipe', () {
      final result = importDoc({
        'name': 'Sad',
        'recipeYield': '1 serving',
        'recipeIngredient': '200 g flour',
      });
      expect(result.recipe, isNull);
      expect(result.issues.single.message, contains('recipeIngredient'));
    });

    test('recipe whose lines all fail yields no recipe but all issues', () {
      final result = importDoc({
        'name': 'Sad',
        'recipeYield': '2 loaves',
        'recipeIngredient': ['salt to taste', 42, ''],
      });
      expect(result.recipe, isNull);
      expect(result.issues, hasLength(3));
    });

    test('amount without name, and negative amounts, are skipped', () {
      final result = importDoc({
        'name': 'Sparse',
        'recipeYield': '1 serving',
        'recipeIngredient': ['2 cups', '2', '-2 cups milk'],
      });
      expect(result.recipe, isNull);
      expect(result.issues, hasLength(3));
    });
  });

  group('step import', () {
    test('absent instructions leave steps empty with no issues', () {
      final result = importDoc({
        'name': 'Plain',
        'recipeYield': '1 bowl',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': ?null,
      });
      expect(result.ok, isTrue);
      expect(result.recipe!.steps, isEmpty);
      expect(result.issues, isEmpty);
    });

    test('single string instruction becomes one step', () {
      final result = importDoc({
        'name': 'Porridge',
        'recipeYield': '1 bowl',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': 'Boil the eggs.',
      });
      expect(result.recipe!.steps, ['Boil the eggs.']);
      expect(result.issues, isEmpty);
    });

    test('list of plain strings keeps order', () {
      final result = importDoc({
        'name': 'Cookies',
        'recipeYield': '24 cookies',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': ['Mix.', 'Chill.', 'Bake.'],
      });
      expect(result.recipe!.steps, ['Mix.', 'Chill.', 'Bake.']);
      expect(result.issues, isEmpty);
    });

    test('HowToStep maps use their text in order', () {
      final result = importDoc({
        'name': 'Cookies',
        'recipeYield': '24 cookies',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          {
            '@type': 'HowToStep',
            'text': 'Preheat the oven.',
          },
          {
            '@type': 'HowToStep',
            'text': 'Bake for 12 minutes.',
          },
        ],
      });
      expect(result.recipe!.steps, ['Preheat the oven.', 'Bake for 12 minutes.']);
      expect(result.issues, isEmpty);
    });

    test('two HowToSections flatten to prefixed steps in order', () {
      final result = importDoc({
        'name': 'Cake',
        'recipeYield': '1 cake',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          {
            '@type': 'HowToSection',
            'name': 'Dough',
            'itemListElement': [
              {'@type': 'HowToStep', 'text': 'Mix the flour.'},
              {'@type': 'HowToStep', 'text': 'Knead until smooth.'},
            ],
          },
          {
            '@type': 'HowToSection',
            'name': 'Glaze',
            'itemListElement': [
              {'@type': 'HowToStep', 'text': 'Whisk the sugar.'},
            ],
          },
        ],
      });
      expect(result.recipe!.steps, [
        'Dough: Mix the flour.',
        'Dough: Knead until smooth.',
        'Glaze: Whisk the sugar.',
      ]);
      expect(result.issues, isEmpty);
    });

    test('mixed strings, HowToSteps, and sections keep document order', () {
      final result = importDoc({
        'name': 'Bread',
        'recipeYield': '1 loaf',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          'Preheat the oven.',
          {
            '@type': 'HowToSection',
            'name': 'Dough',
            'itemListElement': [
              'Knead until smooth.',
              {'@type': 'HowToStep', 'text': 'Rest for an hour.'},
            ],
          },
          {'@type': 'HowToStep', 'text': 'Shape the loaf.'},
        ],
      });
      expect(result.recipe!.steps, [
        'Preheat the oven.',
        'Dough: Knead until smooth.',
        'Dough: Rest for an hour.',
        'Shape the loaf.',
      ]);
      expect(result.issues, isEmpty);
    });

    test('malformed sections add issues and keep salvageable steps', () {
      final result = importDoc({
        'name': 'Bread',
        'recipeYield': '1 loaf',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          'Preheat the oven.',
          {
            '@type': 'HowToSection',
            'name': '   ',
            'itemListElement': [
              {'@type': 'HowToStep', 'text': 'Knead until smooth.'},
            ],
          },
          {'@type': 'HowToSection', 'name': 'Glaze'},
          {'@type': 'HowToStep', 'text': 'Bake.'},
        ],
      });
      expect(result.recipe!.steps, [
        'Preheat the oven.',
        'Knead until smooth.',
        'Bake.',
      ]);
      final messages = result.issues.map((issue) => issue.message);
      expect(messages, hasLength(2));
      expect(messages, contains(contains('section missing name')));
      expect(messages, contains(contains('section missing steps')));
    });

    test('mixed list keeps supported shapes in order and reports two issues', () {
      final result = importDoc({
        'name': 'Cake',
        'recipeYield': '1 cake',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          'Melt the butter.',
          {'@type': 'HowToStep', 'text': 'Stir in the flour.'},
          {'@type': 'HowToSection', 'name': 'Glaze'},
          42,
          {'@type': 'HowToStep', 'text': 'Bake.'},
        ],
      });
      expect(
        result.recipe!.steps,
        ['Melt the butter.', 'Stir in the flour.', 'Bake.'],
      );
      final messages = result.issues.map((issue) => issue.message);
      expect(messages, hasLength(2));
      expect(messages, contains(contains('section missing steps')));
      expect(messages, contains(contains('instruction shape')));
    });

    test('HowToStep without usable text is skipped with an issue', () {
      for (final badText in [null, '', '   ']) {
        final result = importDoc({
          'name': 'Cookies',
          'recipeYield': '24 cookies',
          'recipeIngredient': ['2 eggs'],
          'recipeInstructions': [
            {
              '@type': 'HowToStep',
              'text': ?badText,
            },
          ],
        });
        expect(result.recipe!.steps, isEmpty, reason: '$badText');
        expect(result.issues.single.message, contains('missing text'),
            reason: '$badText');
      }
    });

    test('"@type" given as a list containing HowToStep works', () {
      final result = importDoc({
        'name': 'Pancakes',
        'recipeYield': '8 pancakes',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          {
            '@type': ['HowToStep'],
            'text': 'Whisk the batter.',
          },
        ],
      });
      expect(result.recipe!.steps, ['Whisk the batter.']);
      expect(result.issues, isEmpty);
    });

    test('"@type" case-insensitive HowToStep works', () {
      final result = importDoc({
        'name': 'Pancakes',
        'recipeYield': '8 pancakes',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          {'@type': 'howtostep', 'text': 'Fold in the blueberries.'},
        ],
      });
      expect(result.recipe!.steps, ['Fold in the blueberries.']);
      expect(result.issues, isEmpty);
    });

    test('map without a known instruction type is unsupported', () {
      final result = importDoc({
        'name': 'Stew',
        'recipeYield': '4 bowls',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': [
          {'water': 'first', 'time': '10 min'},
        ],
      });
      expect(result.recipe!.steps, isEmpty);
      expect(result.issues.single.message, contains('instruction shape'));
    });

    test('non-list, non-string instructions report an issue', () {
      final result = importDoc({
        'name': 'Mystery',
        'recipeYield': '1 serving',
        'recipeIngredient': ['2 eggs'],
        'recipeInstructions': 42,
      });
      expect(result.recipe!.steps, isEmpty);
      expect(result.issues.single.message, contains('instruction shape'));
    });
  });
}
