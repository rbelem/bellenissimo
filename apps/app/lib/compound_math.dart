import 'package:bellenissimos_core/core.dart';

/// One rendered group of a recipe's items, in display order.
sealed class CompoundBlock {
  const CompoundBlock();
}

/// Consecutive refs to the same part recipe, collapsed for display.
class RefBlock extends CompoundBlock {
  const RefBlock(this.recipe, this.refs);

  final Recipe recipe;
  final List<ComponentRef> refs;

  int get count => refs.length;

  /// The block's refs' factors summed: its rendered lines are the summed
  /// realizations of each ref, so the combined factor is an addition.
  double get factor => refs.fold(0.0, (sum, ref) => sum + ref.factor);
}

/// One bare ingredient line, in place.
class LeafBlock extends CompoundBlock {
  const LeafBlock(this.line);

  final RecipeLine line;
}

/// One blend use, in place.
class BlendBlock extends CompoundBlock {
  const BlendBlock(this.line);

  final BlendLine line;
}

bool _samePart(Recipe a, Recipe b) =>
    identical(a, b) || (a.id != null && a.id == b.id);

/// Groups a recipe's items into blocks: consecutive refs to the same
/// recipe join one block, every other item splits it.
List<CompoundBlock> compoundBlocks(List<RecipeItem> items) {
  final blocks = <CompoundBlock>[];
  var open = <ComponentRef>[];
  void flush() {
    if (open.isEmpty) return;
    blocks.add(RefBlock(open.first.recipe, List.of(open)));
    open = [];
  }

  for (final item in items) {
    switch (item) {
      case RecipeLine():
        flush();
        blocks.add(LeafBlock(item));
      case BlendLine():
        flush();
        blocks.add(BlendBlock(item));
      case ComponentRef():
        if (open.isEmpty || _samePart(open.first.recipe, item.recipe)) {
          open.add(item);
        } else {
          flush();
          open = [item];
        }
    }
  }
  flush();
  return blocks;
}

/// Grams of one line, or null when the ingredient lacks the bridge the
/// unit needs — the caller never guesses.
double? lineGrams(RecipeLine line) => line.quantity.gramsOf(line.ingredient);

/// Grams a rendered block displays: realized lines plus blend uses, so
/// the card total agrees with the rows above it. Null when any part
/// lacks a bridge — a partial total would be a guess.
double? blockGrams(CompoundBlock block) => switch (block) {
  LeafBlock(:final line) => lineGrams(line),
  BlendBlock(:final line) => line.grams,
  RefBlock(:final refs) => _refsGrams(refs),
};

double? _refsGrams(List<ComponentRef> refs) {
  var sum = 0.0;
  for (final ref in refs) {
    final grams = _realizedGrams(ref.recipe.scaledBy(ref.factor));
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

double? _realizedGrams(Recipe realized) {
  var sum = 0.0;
  for (final item in realized.items) {
    final grams = switch (item) {
      RecipeLine() => lineGrams(item),
      BlendLine() => item.grams,
      ComponentRef() => null,
    };
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
/// bridged, blend uses at face grams, plus each ref's declared yield ×
/// factor. Null when any item is unresolvable — the readout then shows
/// the parts count only, never a guess.
double? compoundEstimateGrams(List<RecipeItem> items) {
  var sum = 0.0;
  for (final item in items) {
    final grams = switch (item) {
      RecipeLine(:final quantity, :final ingredient) =>
        quantity.gramsOf(ingredient),
      BlendLine(:final grams) => grams,
      ComponentRef() => refGrams(item),
    };
    if (grams == null) return null;
    sum += grams;
  }
  return sum;
}

/// Filter clause for unified items: a part recipe's name or a blend's
/// name matches case-insensitively; other recipes match nothing here.
bool compoundItemMatches(Recipe recipe, String query) =>
    recipe.items.any(
      (item) =>
          (item is ComponentRef &&
              item.recipe.name.toLowerCase().contains(query.toLowerCase())) ||
          (item is BlendLine &&
              item.blend.name.toLowerCase().contains(query.toLowerCase())),
    );
