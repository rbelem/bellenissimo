import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

Recipe _recipe({
  String? id,
  List<RecipeLine> lines = const [],
  List<BlendLine> blends = const [],
}) =>
    Recipe(
      id: id,
      name: 'muffins',
      yield: const YieldSpec(count: 12),
      lines: lines,
      blends: blends,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  const sugar = Ingredient('sugar');
  const erythritol = Ingredient('erythritol');
  const egg = Ingredient('egg', roundingStep: 0.5);

  SweetenerBlend blend({String? id, String name = 'berry mix'}) =>
      SweetenerBlend(
        name: name,
        id: id,
        grams: {sugar: 100, erythritol: 100},
        sweetnessPerGram: {sugar: 1.0, erythritol: 0.7},
      );

  group('BlendLine', () {
    test('scaledBy multiplies exactly and keeps the blend instance', () {
      final line = BlendLine(blend(), 10);
      final scaled = line.scaledBy(2.37);
      expect(scaled.grams, 10 * 2.37);
      expect(scaled.blend, same(line.blend));
    });
  });

  group('Recipe blends', () {
    test('a recipe without blends defaults to an empty list', () {
      expect(_recipe(id: 'r1').blends, isEmpty);
    });

    test('attaching a blend does not change yield or timestamps', () {
      final withBlend = _recipe(blends: [BlendLine(blend(), 10)]);
      expect(withBlend.yield.count, 12);
      expect(withBlend.createdAt, DateTime(2026));
      expect(withBlend.updatedAt, DateTime(2026));
    });

    test('scaling doubles attached blend grams and yield', () {
      final b = blend(id: 'berry-1');
      final original = _recipe(blends: [BlendLine(b, 50)]);
      final scaled = original.scaledBy(2);
      expect(scaled.blends.single.blend, same(b));
      expect(scaled.blends.single.grams, 100);
      expect(scaled.yield.count, 24);
      expect(original.blends.single.grams, 50);
      expect(original.yield.count, 12);
      expect(original.blends, isNot(same(scaled.blends)));
    });

    test('blend lines never apply a rounding step', () {
      final original = _recipe(
        lines: [RecipeLine(egg, const Quantity(1, Unit.piece))],
        blends: [BlendLine(blend(), 10)],
      );
      final scaled = original.scaledBy(2.37);
      expect(scaled.lines.single.quantity.amount, 2.5);
      expect(scaled.blends.single.grams, 10 * 2.37);
    });

    test('copyWith replaces blends and preserves everything else', () {
      final original = _recipe(id: 'r1', blends: [BlendLine(blend(), 10)]);
      final next = original.copyWith(blends: [BlendLine(blend(), 20)]);
      expect(next.blends.single.grams, 20);
      expect(next.id, 'r1');
      expect(next.name, 'muffins');
      expect(next.yield.count, 12);
      expect(original.blends.single.grams, 10);
    });
  });

  group('Recipe.replaceBlend', () {
    test('swaps every matching blend line, keeping its grams', () {
      final b = blend(id: 'berry-1');
      final replacement = blend(id: 'berry-1', name: 'new berry');
      final original = _recipe(
        id: 'r1',
        blends: [BlendLine(b, 50), BlendLine(b, 30)],
      );
      final replaced = original.replaceBlend('berry-1', replacement);
      expect(replaced.blends[0].blend, same(replacement));
      expect(replaced.blends[0].grams, 50);
      expect(replaced.blends[1].blend, same(replacement));
      expect(replaced.blends[1].grams, 30);
      expect(replaced.id, 'r1');
      expect(replaced.yield.count, 12);
      expect(replaced.createdAt, original.createdAt);
      expect(replaced.updatedAt, original.updatedAt);
      expect(original.blends[0].blend, same(b));
    });

    test('a null-id blend never matches a replacement walk', () {
      final original = _recipe(blends: [BlendLine(blend(), 10)]);
      expect(
        original.replaceBlend('berry-1', blend(id: 'stand-in')),
        same(original),
      );
    });

    test('a foreign blend id never matches', () {
      final original = _recipe(blends: [BlendLine(blend(id: 'berry-1'), 10)]);
      expect(
        original.replaceBlend('vanilla-1', blend(id: 'stand-in')),
        same(original),
      );
    });
  });

  group('RecipeBook.replacingBlend', () {
    test('walks the book and reuses unchanged recipes by identity', () {
      final b = blend(id: 'berry-1');
      final holder1 = _recipe(id: 'r1', blends: [BlendLine(b, 50)]);
      final holder2 = _recipe(id: 'r2', blends: [BlendLine(b, 30)]);
      final bystander = _recipe(id: 'r3');
      final adHocHolder = _recipe(id: 'r4', blends: [BlendLine(blend(), 10)]);
      final book = RecipeBook([holder1, holder2, bystander, adHocHolder]);

      final replacement = blend(id: 'berry-1', name: 'new berry');
      final next = book.replacingBlend('berry-1', replacement);

      expect(next.byId('r1')!.blends.single.blend, same(replacement));
      expect(next.byId('r1')!.blends.single.grams, 50);
      expect(next.byId('r2')!.blends.single.blend, same(replacement));
      expect(next.byId('r2')!.blends.single.grams, 30);
      expect(next.byId('r3'), same(bystander));
      expect(next.byId('r4'), same(adHocHolder));
      expect(next.recipes.length, 4);
      expect(book.byId('r1')!.blends.single.blend, same(b));
      expect(book.byId('r1')!.blends.single.grams, 50);
    });

    test('a book without the blend reuses every recipe by identity', () {
      final holder = _recipe(id: 'r1', blends: [BlendLine(blend(), 10)]);
      final book = RecipeBook([holder]);
      final next = book.replacingBlend('vanilla-1', blend(id: 'stand-in'));
      expect(next.byId('r1'), same(holder));
    });
  });
}
