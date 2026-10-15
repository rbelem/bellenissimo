import 'package:bellenissimos_app/compound_math.dart';
import 'package:bellenissimos_app/recipe_card.dart';
import 'package:bellenissimos_app/theme.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _egg = Ingredient('egg', gramsPerPiece: 50, roundingStep: 0.5);
const _sugar = Ingredient('sugar');

SweetenerBlend berryMix() => SweetenerBlend(
  name: 'Berry mix',
  id: 'berry-1',
  grams: {_sugar: 100},
  sweetnessPerGram: {_sugar: 0.7},
);

Recipe sponge() => Recipe(
  id: 'sponge',
  name: 'Sponge',
  yield: const YieldSpec(count: 1),
  items: const [
    RecipeLine(Ingredient('flour', gramsPerMl: 0.5), Quantity(300, Unit.g)),
    RecipeLine(_egg, Quantity(1, Unit.piece)),
  ],
);

Recipe filling() => Recipe(
  id: 'filling',
  name: 'Filling',
  yield: const YieldSpec(totalGrams: 400),
  items: const [
    RecipeLine(Ingredient('sugar', gramsPerMl: 0.83), Quantity(200, Unit.g)),
    RecipeLine(Ingredient('butter', gramsPerMl: 0.95), Quantity(150, Unit.g)),
  ],
);

Recipe jammySponge() => Recipe(
  id: 'jammy-sponge',
  name: 'Jammy sponge',
  yield: const YieldSpec(count: 1),
  items: [sponge().items[0] as RecipeLine, BlendLine(berryMix(), 50)],
);

/// sponge ×3, filling ×1, one bare leaf — assembly order and collapse
/// fodder.
Recipe torte() => Recipe.compound(
  id: 'torte',
  name: 'Torte',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(
    name: 'Torte',
    components: [
      ComponentRef(sponge(), factor: 1),
      ComponentRef(sponge(), factor: 1),
      ComponentRef(sponge(), factor: 1),
      ComponentRef(filling(), factor: 1),
      const RecipeLine(Ingredient('powdered_sugar'), Quantity(30, Unit.g)),
    ],
  ),
);

/// [yield] is a reserved word in async bodies; compound builders keep
/// it at top level.
Recipe dishOf(RecipeItem item) => Recipe.compound(
  id: 'torte',
  name: 'Torte',
  yield: const YieldSpec(count: 1),
  tree: RecipeTree(name: 'Torte', components: [item]),
);

Future<void> pumpCard(
  WidgetTester tester,
  Recipe recipe, {
  double? target,
  MassUnit massUnit = MassUnit.g,
}) =>
    tester.pumpWidget(
      MaterialApp(
        theme: recipeBoxLight,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipeCard(
              recipe: recipe,
              target: target ?? 1,
              activeScale: null,
              subs: const {},
              massUnit: massUnit,
              book: RecipeBook(const []),
              panDraft: PanDraft(),
              openBlendRows: const {},
              onToggleBlendRow: (_) {},
              onScale: (_) {},
              onScaleStart: () {},
              onScaleEnd: () {},
              onMenu: () {},
              onSubstitute: (_) {},
              onPanChanged: () {},
            ),
          ),
        ),
      ),
    );

void main() {
  group('compound math', () {
    test('collapses only consecutive same-recipe refs into counted blocks',
        () {
      final s = sponge();
      final f = filling();
      final blocks = compoundBlocks([
        ComponentRef(s, factor: 1),
        ComponentRef(s, factor: 1),
        ComponentRef(f, factor: 1),
        ComponentRef(s, factor: 1),
      ]);
      expect(blocks.length, 3);
      expect((blocks[0] as RefBlock).recipe.name, 'Sponge');
      expect((blocks[0] as RefBlock).count, 2);
      expect((blocks[1] as RefBlock).recipe.name, 'Filling');
      expect((blocks[2] as RefBlock).recipe.name, 'Sponge');
      expect((blocks[2] as RefBlock).count, 1);
    });

    test('bare leaves become label-less blocks in place', () {
      final blocks = compoundBlocks([
        const RecipeLine(Ingredient('cocoa'), Quantity(30, Unit.g)),
        ComponentRef(sponge(), factor: 1),
      ]);
      expect(blocks.length, 2);
      final leaf = blocks[0] as LeafBlock;
      expect(leaf.line.ingredient.id, 'cocoa');
      expect((blocks[1] as RefBlock).recipe.name, 'Sponge');
    });

    test('blend uses become their own blocks and split ref runs', () {
      final s = sponge();
      final blocks = compoundBlocks([
        ComponentRef(s, factor: 1),
        BlendLine(berryMix(), 40),
        ComponentRef(s, factor: 1),
      ]);
      expect(blocks.length, 3);
      expect(blocks[0], isA<RefBlock>());
      expect((blocks[1] as BlendBlock).line.grams, 40);
      expect((blocks[2] as RefBlock).count, 1);
    });

    test('the card total sums realized lines so it matches the rows', () {
      final blocks = compoundBlocks(torte().items);
      expect(dishGrams(blocks), 900 + 150 + 350 + 30);
      expect(blockGrams(blocks[0]), 900 + 150);
    });

    test('block grams include a part blend at face grams', () {
      final blocks = compoundBlocks([ComponentRef(jammySponge(), factor: 2)]);
      expect(blockGrams(blocks.single), 600 + 100);
    });

    test('estimate sums ref yields by factor and bridges leaf lines', () {
      final items = <RecipeItem>[
        ComponentRef(filling(), factor: 0.5),
        const RecipeLine(
          Ingredient('water', gramsPerMl: 1.0),
          Quantity(120, Unit.g),
        ),
        const RecipeLine(
          Ingredient('egg', gramsPerPiece: 50),
          Quantity(2, Unit.piece),
        ),
      ];
      expect(compoundEstimateGrams(items), 200 + 120 + 100);
    });

    test('the estimate counts blend uses at face grams', () {
      final items = <RecipeItem>[
        ComponentRef(filling(), factor: 0.5),
        BlendLine(berryMix(), 40),
      ];
      expect(compoundEstimateGrams(items), 200 + 40);
    });

    test('totals are null when a component cannot resolve — never guesses',
        () {
      final items = <RecipeItem>[
        ComponentRef(filling(), factor: 1),
        const RecipeLine(Ingredient('mystery'), Quantity(2, Unit.piece)),
      ];
      expect(compoundEstimateGrams(items), isNull);
      expect(dishGrams(compoundBlocks(items)), isNull);
    });

    test('a nested ref inside a part hides the total instead of guessing',
        () {
      final inner = Recipe(
        id: 'inner',
        name: 'Inner',
        yield: const YieldSpec(count: 1),
        items: [ComponentRef(sponge(), factor: 1)],
      );
      final blocks = compoundBlocks([ComponentRef(inner, factor: 1)]);
      expect(dishGrams(blocks), isNull);
    });

    test('the filter clause reads part and blend names, case-insensitively',
        () {
      final dish = Recipe.compound(
        id: 'torte',
        name: 'Torte',
        yield: const YieldSpec(count: 1),
        tree: RecipeTree(
          name: 'Torte',
          components: [
            ComponentRef(sponge(), factor: 1),
            BlendLine(berryMix(), 40),
          ],
        ),
      );
      expect(compoundItemMatches(dish, 'spon'), isTrue);
      expect(compoundItemMatches(dish, 'SPONGE'), isTrue);
      expect(compoundItemMatches(dish, 'berry'), isTrue);
      expect(compoundItemMatches(dish, 'torte'), isFalse);
      expect(compoundItemMatches(sponge(), 'sponge'), isFalse);
    });
  });

  group('compound card', () {
    testWidgets('renders part blocks in assembly order with the ×3 collapse',
        (tester) async {
      await pumpCard(tester, torte());

      expect(tester.takeException(), isNull);
      expect(find.text('Sponge × 3'), findsOneWidget);
      expect(find.text('Filling'), findsOneWidget);
      double dy(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(dy('Sponge × 3') < dy('Filling'), isTrue);
      expect(dy('Filling') < dy('30 g powdered_sugar'), isTrue);
    });

    testWidgets('part lines render summed realizations of the collapsed refs',
        (tester) async {
      await pumpCard(tester, torte());

      expect(find.text('900 g flour'), findsOneWidget);
      expect(find.text('3 piece egg'), findsOneWidget);
      expect(find.text('200 g sugar'), findsOneWidget);
      expect(find.text('150 g butter'), findsOneWidget);
      expect(find.text('30 g powdered_sugar'), findsOneWidget);
    });

    testWidgets('a part blend renders as an attached row inside the block',
        (tester) async {
      await pumpCard(tester, dishOf(ComponentRef(jammySponge(), factor: 1)));

      expect(find.text('Jammy sponge'), findsOneWidget);
      expect(find.text('300 g flour'), findsOneWidget);
      expect(find.text('50 g Berry mix'), findsOneWidget);
    });

    testWidgets('a part factor other than ×1 shows in pencil beside the label',
        (tester) async {
      await pumpCard(tester, dishOf(ComponentRef(sponge(), factor: 0.75)));

      expect(find.text('Sponge × 0.75'), findsOneWidget);
      expect(find.text('225 g flour'), findsOneWidget);
      expect(find.text('1 piece egg'), findsOneWidget);
    });

    testWidgets('the total line sums the dish in grams, never red',
        (tester) async {
      await pumpCard(tester, torte());

      final total = find.byKey(const ValueKey('torte-total'));
      expect(total, findsOneWidget);
      expect(tester.widget<Text>(total).data, 'Total 1430 g');
      final context = tester.element(total);
      expect(
        tester.widget<Text>(total).style!.color,
        Theme.of(context).extension<BoxTokens>()!.onCard,
      );
    });

    testWidgets('scaling realizes each ref once, so rounding snaps once',
        (tester) async {
      await pumpCard(
        tester,
        dishOf(ComponentRef(sponge(), factor: 0.3)),
        target: 2,
      );

      expect(find.text('180 g flour'), findsOneWidget);
      expect(find.text('0.5 piece egg'), findsOneWidget);
    });

    testWidgets('a deleted part recipe still renders from the tree snapshot',
        (tester) async {
      await pumpCard(tester, torte());

      expect(tester.takeException(), isNull);
      expect(find.text('Sponge × 3'), findsOneWidget);
      expect(find.text('900 g flour'), findsOneWidget);
    });

    testWidgets('the mass toggle reaches block rows and the total', (
      tester,
    ) async {
      await pumpCard(tester, torte(), massUnit: MassUnit.oz);

      expect(find.text('31.7 oz flour'), findsOneWidget);
      expect(find.text('3 piece egg'), findsOneWidget);
      expect(find.text('Total 50.4 oz'), findsOneWidget);
    });
  });
}
