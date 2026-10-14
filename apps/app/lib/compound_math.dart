import 'package:bellenissimos_core/core.dart';

/// One rendered group of a compound tree. Consecutive refs to the same
/// part recipe collapse into one counted block; bare leaves render as
/// label-less blocks at their position in assembly order.
class CompoundBlock {
  const CompoundBlock.ref(this.recipe, this.refs) : leaves = const [];

  const CompoundBlock.leaf(this.leaves)
      : recipe = null,
        refs = const [];

  /// The part recipe of a ref block; null for a bare leaf block.
  final Recipe? recipe;

  final List<ComponentRef> refs;

  final List<RecipeLine> leaves;

  int get count => refs.length;

  /// The block's refs' factors summed: its rendered lines are the summed
  /// realizations of each ref, so the combined factor is an addition.
  double get factor => refs.fold(0.0, (sum, ref) => sum + ref.factor);
}

bool _samePart(Recipe a, Recipe b) =>
    identical(a, b) || (a.id != null && a.id == b.id);

/// Groups a tree's components into blocks: consecutive refs to the same
/// recipe join one block, every other component splits it.
List<CompoundBlock> compoundBlocks(RecipeTree tree) {
  final blocks = <CompoundBlock>[];
  var open = <ComponentRef>[];
  void flush() {
    if (open.isEmpty) return;
    blocks.add(CompoundBlock.ref(open.first.recipe, List.of(open)));
    open = [];
  }

  for (final component in tree.components) {
    switch (component) {
      case ComponentLeaf(:final line):
        flush();
        blocks.add(CompoundBlock.leaf([line]));
      case ComponentRef():
        if (open.isEmpty || _samePart(open.first.recipe, component.recipe)) {
          open.add(component);
        } else {
          flush();
          open = [component];
        }
    }
  }
  flush();
  return blocks;
}

/// Grams of one line, or null when the ingredient lacks the bridge the
/// unit needs — the caller never guesses.
double? lineGrams(RecipeLine line) => line.quantity.gramsOf(line.ingredient);

/// Grams a rendered block displays, summed from its realized lines, so
/// the card total agrees with the rows above it. Null when any line
/// lacks a bridge.
double? blockGrams(CompoundBlock block) {
  if (block.recipe == null) return _linesGrams(block.leaves);
  var sum = 0.0;
  for (final ref in block.refs) {
    final grams = _linesGrams(ref.recipe.scaledBy(ref.factor).lines);
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

double? _linesGrams(Iterable<RecipeLine> lines) {
  var sum = 0.0;
  for (final line in lines) {
    final grams = lineGrams(line);
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

/// The card total: every block resolvable, or null — a partial total
/// would be a guess.
double? dishGrams(List<CompoundBlock> blocks) {
  var sum = 0.0;
  for (final block in blocks) {
    final grams = blockGrams(block);
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

/// Grams a ref contributes by its part's declared yield, or null when
/// the part declares no gram yield.
double? refGrams(ComponentRef ref) {
  final total = ref.recipe.yield.totalGrams;
  return total == null ? null : total * ref.factor;
}

/// Authoring-time estimate behind the editor readout: leaf lines
/// bridged plus each ref's declared yield × factor. Null when any
/// component is unresolvable — the readout then shows the parts count
/// only, never a guess.
double? compoundEstimateGrams(RecipeTree tree) {
  var sum = 0.0;
  for (final component in tree.components) {
    final grams = switch (component) {
      ComponentLeaf(:final line) => lineGrams(line),
      ComponentRef() => refGrams(component),
    };
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

/// Filter clause for compounds: a part recipe's name matches
/// case-insensitively; plain recipes match nothing here.
bool compoundPartMatches(Recipe recipe, String query) =>
    recipe.tree?.components.any(
          (component) =>
              component is ComponentRef &&
              component.recipe.name
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        ) ??
    false;
