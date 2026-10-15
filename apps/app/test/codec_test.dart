import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/recipe_codec.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _batter() => Recipe(
  id: 'batter',
  name: 'Batter',
  yield: const YieldSpec(count: 1),
  items: [
    RecipeLine(
      const Ingredient('flour', gramsPerMl: 0.6),
      const Quantity(500, Unit.g),
    ),
  ],
);

SweetenerBlend _berry() => SweetenerBlend(
  name: 'berry mix',
  id: 'berry-1',
  grams: {const Ingredient('sugar'): 100},
  sweetnessPerGram: {const Ingredient('sugar'): 0.7},
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
      RecipeLine(const Ingredient('salt'), const Quantity(5, Unit.g)),
      BlendLine(_berry(), 40),
    ],
  ),
);

/// A version-3 document: `lines` and `blends` beside an optional `tree`.
Map<String, Object?> _v3Doc({
  List<Object?> lines = const [],
  List<Object?> blends = const [],
  Map<String, Object?>? tree,
}) => {
  'id': 'cake',
  'name': 'Cake',
  'parentId': null,
  'yield': {'count': 1, 'totalGrams': null},
  'createdAt': null,
  'updatedAt': null,
  'steps': const <String>[],
  'lines': lines,
  'blends': blends,
  'tree': tree,
};

Map<String, Object?> _v3Tree(List<Object?> components) => {
  'name': 'assembled cake',
  'components': components,
};

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
      items: [RecipeLine(yeast, const Quantity(7, Unit.g))],
    );

    final restored = RecipeCodec.decode(RecipeCodec.encode(recipe));

    final line = restored.items.single as RecipeLine;
    expect(line.ingredient.scalingExponent, 0.7);
    expect(line.ingredient.gramsPerMl, 0.6);
  });

  test('codec roundtrip keeps a linear ingredient exponent-free', () {
    final flour = const Ingredient('flour', gramsPerMl: 0.6);
    final recipe = Recipe(
      id: 'flat',
      name: 'Flat',
      yield: const YieldSpec(count: 1),
      items: [RecipeLine(flour, const Quantity(500, Unit.g))],
    );

    final restored = RecipeCodec.decode(RecipeCodec.encode(recipe));

    final line = restored.items.single as RecipeLine;
    expect(line.ingredient.scalingExponent, isNull);
  });

  test('codec roundtrips every item kind in order', () {
    final restored = RecipeCodec.decode(RecipeCodec.encode(_compound()));

    expect(restored.isCompound, isTrue);
    expect(restored.items, hasLength(3));
    final ref = restored.items[0] as ComponentRef;
    expect(ref.factor, 2);
    expect(ref.recipe.id, 'batter');
    final batterLine = ref.recipe.items.single as RecipeLine;
    expect(batterLine.ingredient.id, 'flour');
    expect(batterLine.ingredient.gramsPerMl, 0.6);
    expect(batterLine.quantity.amount, 500);
    final leaf = restored.items[1] as RecipeLine;
    expect(leaf.ingredient.id, 'salt');
    expect(leaf.quantity.amount, 5);
    final blend = restored.items[2] as BlendLine;
    expect(blend.blend.name, 'berry mix');
    expect(blend.grams, 40);
  });

  test('codec roundtrips a nested ref', () {
    final tart = Recipe.compound(
      id: 'tart',
      name: 'Tart',
      yield: const YieldSpec(count: 1),
      tree: RecipeTree(
        name: 'tart shell',
        components: [
          RecipeLine(const Ingredient('butter'), const Quantity(120, Unit.g)),
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

    final ref = restored.items.single as ComponentRef;
    expect(ref.factor, 1.5);
    final inner = ref.recipe.items.single as RecipeLine;
    expect(inner.ingredient.id, 'butter');
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

  test('an item that is neither a line, a blend, nor a ref is rejected', () {
    final doc = RecipeCodec.encode(_batter());
    (doc['items']! as List<Object?>).add({'name': 'junk'});

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });

  test('a legacy doc decodes lines then blends into items', () {
    final lineDoc = {
      'ingredient': 'flour',
      'gramsPerMl': 0.6,
      'gramsPerPiece': null,
      'roundingStep': null,
      'scalingExponent': null,
      'value': 500,
      'unit': 'g',
    };
    final blend = _berry();
    final doc = _v3Doc(
      lines: [lineDoc],
      blends: [BlendCodec.encodeLine(BlendLine(blend, 100))],
    );

    final restored = RecipeCodec.decode(doc);

    expect(restored.items, hasLength(2));
    expect(
      (restored.items[0] as RecipeLine).ingredient.gramsPerMl,
      0.6,
    );
    expect((restored.items[1] as BlendLine).grams, 100);
  });

  test('a legacy tree decodes its refs and leaves into items', () {
    final refDoc = {
      'ref': RecipeCodec.encode(_batter()),
      'factor': 2,
    };
    final leafDoc = {
      'leaf': {
        'ingredient': 'salt',
        'gramsPerMl': null,
        'gramsPerPiece': null,
        'roundingStep': null,
        'scalingExponent': null,
        'value': 5,
        'unit': 'g',
      },
    };
    final doc = _v3Doc(tree: _v3Tree([refDoc, leafDoc]));

    final restored = RecipeCodec.decode(doc);

    expect(restored.isCompound, isTrue);
    expect((restored.items[0] as ComponentRef).factor, 2);
    expect(
      ((restored.items[0] as ComponentRef).recipe.items.single as RecipeLine)
          .ingredient
          .id,
      'flour',
    );
    expect((restored.items[1] as RecipeLine).quantity.amount, 5);
  });

  test('a legacy doc carrying a tree and lines is rejected at decode', () {
    final batterLines =
        RecipeCodec.encode(_batter())['items']! as List<Object?>;
    final doc = _v3Doc(
      lines: [batterLines.first],
      tree: _v3Tree(const []),
    );

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });

  test('a legacy doc carrying a tree and blends is rejected at decode', () {
    final blend = SweetenerBlend(
      name: 'mix',
      grams: {const Ingredient('honey'): 60},
      sweetnessPerGram: {const Ingredient('honey'): 1.1},
    );
    final doc = _v3Doc(
      blends: [BlendCodec.encodeLine(BlendLine(blend, 100))],
      tree: _v3Tree(const []),
    );

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });

  test('a legacy tree component that is neither leaf nor ref is rejected', () {
    final doc = _v3Doc(
      tree: _v3Tree([
        {'name': 'junk'},
      ]),
    );

    expect(() => RecipeCodec.decode(doc), throwsArgumentError);
  });
}
