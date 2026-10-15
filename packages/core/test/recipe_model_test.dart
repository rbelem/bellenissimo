import 'package:bellenissimos_core/core.dart';
import 'package:test/test.dart';

void main() {
  final created = DateTime(2026, 1, 15, 10, 30);
  final updated = DateTime(2026, 2, 1, 8, 0);
  const flour = Ingredient('flour', gramsPerMl: 0.5);
  final line = RecipeLine(flour, const Quantity(250, Unit.g));
  final base = Recipe(
    id: 'butter-cookies',
    name: 'butter cookies',
    yield: const YieldSpec(count: 24),
    items: [line],
    steps: const ['cream butter and sugar', 'fold in flour', 'pipe and bake'],
    createdAt: created,
    updatedAt: updated,
  );

  group('recipe identity, steps, and timestamps', () {
    test('steps default to empty', () {
      const bare = Recipe(name: 'x', yield: YieldSpec(), items: []);
      expect(bare.steps, isEmpty);
    });

    test('identity and timestamps default to null', () {
      const bare = Recipe(name: 'x', yield: YieldSpec(), items: []);
      expect(bare.id, isNull);
      expect(bare.parentId, isNull);
      expect(bare.createdAt, isNull);
      expect(bare.updatedAt, isNull);
    });

    test('all fields round-trip', () {
      expect(base.id, 'butter-cookies');
      expect(base.steps, hasLength(3));
      expect(base.steps[1], 'fold in flour');
      expect(base.createdAt, created);
      expect(base.updatedAt, updated);
    });
  });

  group('recipe copyWith', () {
    test('overrides only the given fields', () {
      final derived = base.copyWith(parentId: 'butter-cookies', steps: const [
        'mix',
        'bake',
      ]);
      expect(derived.parentId, 'butter-cookies');
      expect(derived.steps, ['mix', 'bake']);
      expect(derived.id, 'butter-cookies');
      expect(derived.name, 'butter cookies');
      expect(derived.yield, base.yield);
      expect(derived.items, base.items);
      expect(derived.createdAt, created);
    });

    test('can reassign id and timestamps', () {
      final later = DateTime(2026, 3, 1);
      final renamed = base.copyWith(
        id: 'egg-free-cookies',
        updatedAt: later,
      );
      expect(renamed.id, 'egg-free-cookies');
      expect(renamed.updatedAt, later);
    });

    test('the original is untouched', () {
      base.copyWith(id: 'other', steps: const ['x']);
      expect(base.id, 'butter-cookies');
      expect(base.steps, hasLength(3));
    });
  });

  group('recipe book', () {
    final eggFree = base.copyWith(
      id: 'egg-free-cookies',
      parentId: 'butter-cookies',
      steps: const ['cream', 'fold', 'pipe'],
    );
    final glutenFree = base.copyWith(
      id: 'gf-cookies',
      parentId: 'butter-cookies',
    );
    final loaf = Recipe(
      id: 'sandwich-loaf',
      name: 'sandwich loaf',
      yield: const YieldSpec(totalGrams: 900),
      items: const [],
    );
    final anonymous = Recipe(
      name: 'butter cookies',
      yield: const YieldSpec(count: 24),
      items: [line],
      parentId: 'butter-cookies',
    );

    final book = RecipeBook([base, eggFree, glutenFree, loaf, anonymous]);

    test('derivativesOf lists children in insertion order', () {
      expect(
        book.derivativesOf('butter-cookies').map((r) => r.id),
        ['egg-free-cookies', 'gf-cookies', null],
      );
    });

    test('derivativesOf returns empty when there are none', () {
      expect(book.derivativesOf('sandwich-loaf'), isEmpty);
      expect(book.derivativesOf('unknown'), isEmpty);
    });

    test('a derivative without its own id is still listed', () {
      expect(book.derivativesOf('butter-cookies'), contains(anonymous));
    });

    test('byId resolves and misses', () {
      expect(book.byId('sandwich-loaf')?.name, 'sandwich loaf');
      expect(book.byId('nope'), isNull);
    });

    test('duplicate ids are rejected', () {
      final twin = base.copyWith(parentId: null);
      expect(
        () => RecipeBook([base, twin]),
        throwsArgumentError,
      );
    });

    test('multiple recipes without ids are allowed', () {
      final a = const Recipe(name: 'a', yield: YieldSpec(), items: []);
      final b = const Recipe(name: 'b', yield: YieldSpec(), items: []);
      expect(() => RecipeBook([a, b]), returnsNormally);
    });
  });
}
