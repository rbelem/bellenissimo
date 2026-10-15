import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'compound_math.dart';
import 'rolling.dart';
import 'theme.dart';

/// Display unit for mass quantities.
enum MassUnit { g, oz }

/// One target-pan draft for a card.
class PanDraft {
  PanDraft({
    this.shape = PanShape.round,
    this.dim1 = '20',
    this.dim2 = '',
    this.depth = '5',
  });

  PanShape shape;
  String dim1;
  String dim2;
  String depth;

  Pan? build() {
    final d1 = double.tryParse(dim1);
    final depth = double.tryParse(this.depth);
    if (d1 == null || depth == null || depth <= 0 || d1 <= 0) return null;
    return switch (shape) {
      PanShape.round => Pan.round(d1, depth),
      PanShape.square => Pan.square(d1, depth),
      PanShape.rectangular => Pan.rectangular(
        d1,
        double.tryParse(dim2) ?? d1,
        depth,
      ),
    };
  }
}

/// Stable scale-control prefixes for the seeded cards, so widget keys in
/// tests and integrations stay put. Anything new derives its prefix from
/// its id.
const seedPrefixes = <String, String>{
  'butter-cookies': 'cookies',
  'sandwich-loaf': 'loaf',
  'egg-free-cookies': 'eggfree',
};

const _seedPieceNouns = <String, String>{'cookies': ' cookies'};

/// Built-in mass-equivalence swaps, offered per line via long-press.
/// gramsPerGram comes from the seeds' densities (with.gramsPerMl /
/// from.gramsPerMl) so both directions weigh the same. Substitutions are
/// a VIEW over a card — the source recipe never changes.
final substitutionTable = <String, List<Substitution>>{
  'butter': [
    Substitution(
      'butter',
      seedIngredients['oil']!,
      gramsPerGram: 0.95 / 0.9,
      note: 'melted, same volume roughly',
    ),
  ],
  'sugar': [
    Substitution(
      'sugar',
      seedIngredients['honey']!,
      gramsPerGram: 0.83 / 1.42,
      note: 'reduce oven by 10 C',
    ),
  ],
  'egg': [
    Substitution(
      'egg',
      Ingredient('applesauce', gramsPerMl: 1.02),
      gramsPerGram: 50 / 102,
      note: 'the egg-free move',
    ),
  ],
};

/// The reference pan new pan calculations start from: a 20 cm round tin,
/// 5 cm deep — the most common cake pan. Factors above ×1 mean a bigger
/// pan than the recipe was written for.
final Pan _referencePan = Pan.round(20, 5);

Duration? _baseBakeTime(Recipe recipe) {
  for (final step in recipe.steps) {
    final match = RegExp(r'for (\d+) minutes').firstMatch(step);
    if (match != null) return Duration(minutes: int.parse(match.group(1)!));
  }
  return null;
}

/// "created yyyy-mm-dd · updated yyyy-mm-dd", or null when undated.
String? dateLine(DateTime? created, DateTime? updated) {
  if (created == null || updated == null) return null;
  return 'created ${_ymd(created)} · updated ${_ymd(updated)}';
}

String? timestampLine(Recipe recipe) =>
    dateLine(recipe.createdAt, recipe.updatedAt);

String _ymd(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

/// A quantity in the card's display unit: ounces with one decimal under
/// the mass toggle, grams otherwise.
String quantityText(Quantity quantity) {
  if (quantity.unit == Unit.oz && quantity.amount % 1 != 0) {
    return '${quantity.amount.toStringAsFixed(1)} oz';
  }
  if (quantity.unit == Unit.g && quantity.amount % 1 != 0) {
    return '${quantity.amount.round()} g';
  }
  return '$quantity';
}

/// One recipe card: scaled lines, yield, target, scale slider, pan
/// adaptation and steps. All mutable state lives in the page; the card
/// renders and reports intent back through the callbacks.
class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    required this.target,
    required this.activeScale,
    required this.subs,
    required this.massUnit,
    required this.book,
    required this.panDraft,
    required this.openBlendRows,
    required this.onToggleBlendRow,
    required this.onScale,
    required this.onScaleStart,
    required this.onScaleEnd,
    required this.onMenu,
    required this.onSubstitute,
    required this.onPanChanged,
  });

  final Recipe recipe;
  final double target;
  final String? activeScale;
  final Map<String, Substitution> subs;
  final MassUnit massUnit;
  final RecipeBook book;
  final PanDraft panDraft;

  /// Row keys whose attached blend is expanded; ephemeral view state
  /// owned by the page, like substitutions.
  final Set<String> openBlendRows;

  final ValueChanged<String> onToggleBlendRow;
  final ValueChanged<double> onScale;
  final VoidCallback onScaleStart;
  final VoidCallback onScaleEnd;
  final VoidCallback onMenu;
  final ValueChanged<RecipeLine> onSubstitute;
  final VoidCallback onPanChanged;

  String get _prefix => seedPrefixes[recipe.id] ?? recipe.id!;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final raw = recipe;
    final prefix = _prefix;
    final base = raw.yield.count ?? raw.yield.totalGrams;
    final isScaled = target != base;
    final scaled = raw.scaledBy(target / base!);
    final dated = timestampLine(raw);
    final scaleLo = base / 2;
    final scaleHi = base * 2;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      opacity: activeScale == null || activeScale == prefix ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 3),
              blurRadius: 10,
              color: Color(0x52241710),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, top: 8),
                      child: Text(raw.name, style: boxTitle(context)),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('menu-${raw.id}'),
                    icon: const Icon(Icons.more_vert, size: 20),
                    tooltip: '${raw.name} actions',
                    onPressed: onMenu,
                  ),
                ],
              ),
              if (dated != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dated,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        color: tokens.pencil,
                      ),
                    ),
                  ),
                ),
              ..._familyLines(context, raw),
              const SizedBox(height: 8),
              ..._compoundSection(context, scaled, prefix),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: rollIn(
                  context,
                  _yieldText(scaled, raw),
                  Text(
                    _yieldText(scaled, raw),
                    key: ValueKey('$prefix-yield'),
                    style: boxQuantity(context, size: 15.5).copyWith(
                      fontWeight: FontWeight.w700,
                      color: isScaled ? tokens.accent : tokens.onCard,
                      decoration: isScaled
                          ? TextDecoration.underline
                          : TextDecoration.none,
                      decorationColor: tokens.accent,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 2),
                child: rollIn(
                  context,
                  _targetText(raw, target),
                  Text(
                    _targetText(raw, target),
                    key: ValueKey('$prefix-target'),
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 0.5,
                      color: tokens.pencil,
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: isScaled || activeScale == prefix
                      ? tokens.accent
                      : tokens.rule,
                  thumbColor: isScaled || activeScale == prefix
                      ? tokens.accent
                      : tokens.pencil,
                ),
                child: Semantics(
                  label: 'Scale ${raw.name} yield',
                  child: Slider(
                    key: ValueKey('$prefix-slider'),
                    value: target,
                    min: scaleLo,
                    max: scaleHi,
                    onChanged: onScale,
                    onChangeStart: (_) => onScaleStart(),
                    onChangeEnd: (_) => onScaleEnd(),
                  ),
                ),
              ),
              if (_baseBakeTime(raw) != null)
                _panSection(context, raw, prefix, _baseBakeTime(raw)!),
              if (raw.steps.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < raw.steps.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${i + 1}. ${raw.steps[i]}',
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: tokens.onCard,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _familyLines(BuildContext context, Recipe recipe) sync* {
    final parentId = recipe.parentId;
    if (parentId != null) {
      final parent = book.byId(parentId);
      if (parent != null) {
        yield Text('variant of ${parent.name}', style: boxAnnotation(context));
      }
    }
    final id = recipe.id;
    if (id == null) return;
    final variants = book.derivativesOf(id);
    if (variants.isEmpty) return;
    yield Text(
      'variants: ${variants.map((r) => r.name).join(', ')}',
      style: boxAnnotation(context),
    );
  }

  Quantity _displayGrams(double grams) {
    final quantity = Quantity(grams, Unit.g);
    return massUnit == MassUnit.oz ? quantity.convertTo(Unit.oz) : quantity;
  }

  /// Attached blends ride the recipe's scale pass: the collapsed row
  /// shows the scaled grams, expanded parts recompute from it in one
  /// pass, display rounding only — no part rounding step ever applies.
  /// A top-level blend uses the plain row key; a part's blend takes an
  /// explicit key so collapsed refs never share one.
  Widget _blendTile(
    BuildContext context,
    BlendLine line,
    String prefix, {
    String? keyOverride,
  }) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final blend = line.blend;
    final rowKey = keyOverride ?? '$prefix-line-${blend.id ?? blend.name}';
    final open = openBlendRows.contains(rowKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.rule)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Semantics(
              label: 'Show ${blend.name} composition',
              child: ListTile(
                key: ValueKey(rowKey),
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onTap: () => onToggleBlendRow(rowKey),
                title: Text(
                  '${quantityText(_displayGrams(line.grams))} ${blend.name}',
                  style: boxQuantity(context),
                ),
                trailing: Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  key: ValueKey('$rowKey-toggle'),
                  size: 20,
                  color: tokens.pencil,
                ),
              ),
            ),
          ),
        ),
        if (open) ..._blendParts(context, line, rowKey),
      ],
    );
  }

  List<Widget> _blendParts(
    BuildContext context,
    BlendLine line,
    String rowKey,
  ) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final blend = line.blend;
    final parts = <Widget>[
      for (final entry in blend.grams.entries)
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.rule)),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: ValueKey('$rowKey-part-${entry.key.id}'),
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.only(left: 20, right: 4),
              title: Text(
                '${quantityText(_displayGrams(line.grams * entry.value / blend.totalGrams))} ${entry.key.id}',
                style: boxQuantity(context, size: 13.5),
              ),
            ),
          ),
        ),
    ];
    if (blend is SweetenerBlend) {
      final sugarGrams = line.grams * blend.sucroseEquivalentPerGram;
      parts.add(
        Padding(
          padding: const EdgeInsets.only(left: 20, top: 4),
          child: Text(
            'sweetness of ≈ ${sugarGrams.round()} g sugar',
            key: ValueKey('$rowKey-sugar-equiv'),
            style: boxQuantity(
              context,
              size: 12.5,
            ).copyWith(color: tokens.pencil),
          ),
        ),
      );
      if (blend.losesBulk) {
        parts.add(
          Padding(
            padding: const EdgeInsets.only(left: 20, bottom: 4),
            child: Text(
              "won't bulk like sugar — structure will shift",
              key: ValueKey('$rowKey-bulk-note'),
              style: boxAnnotation(context, size: 14),
            ),
          ),
        );
      }
    }
    return parts;
  }

  /// Every item in display order: leaf lines render as plain rows,
  /// blend uses as attached rows, ref runs collapse into part blocks.
  /// Plain recipes render exactly their old rows. A compound adds the
  /// dish total — Courier 700, never red, because size is a property of
  /// the card, not a change.
  List<Widget> _compoundSection(
    BuildContext context,
    Recipe scaled,
    String prefix,
  ) {
    final blocks = compoundBlocks(scaled.items);
    final totalGrams = scaled.isCompound ? dishGrams(blocks) : null;
    return [
      for (var b = 0; b < blocks.length; b++)
        ..._block(context, blocks[b], b, prefix),
      if (totalGrams != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(
            'Total ${quantityText(_displayGrams(totalGrams))}',
            key: ValueKey('$prefix-total'),
            style: boxQuantity(
              context,
              size: 15.5,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
    ];
  }

  List<Widget> _block(
    BuildContext context,
    CompoundBlock block,
    int b,
    String prefix,
  ) => switch (block) {
    LeafBlock(:final line) => [
      rollIn(
        context,
        '${_displayQuantity(line)} ${line.ingredient.id}',
        _lineTile(context, line, prefix),
      ),
    ],
    BlendBlock(:final line) => [
      rollIn(
        context,
        '${quantityText(_displayGrams(line.grams))} ${line.blend.name}',
        _blendTile(context, line, prefix),
      ),
    ],
    RefBlock() => _partBlock(context, block, b, prefix),
  };

  /// A part block: the Caveat label carrying the part recipe's name —
  /// with the collapse count and a non-×1 factor penciled beside it —
  /// over that part's ruled Courier lines, then the part's own blend
  /// uses at their realized grams.
  List<Widget> _partBlock(
    BuildContext context,
    RefBlock block,
    int b,
    String prefix,
  ) {
    final rows = _blockRows(block);
    return [
      Padding(
        padding: const EdgeInsets.only(left: 8, top: 6),
        child: Text(
          _blockLabel(block),
          key: ValueKey('$prefix-comp-$b-label'),
          style: boxAnnotation(context),
        ),
      ),
      for (final row in rows)
        rollIn(
          context,
          row.text,
          _ruledRow(context, '$prefix-comp-$b-line-${row.key}', row.text),
        ),
      for (var r = 0; r < block.refs.length; r++)
        for (final blend in _refBlends(block.refs[r]))
          rollIn(
            context,
            '${quantityText(_displayGrams(blend.grams))} ${blend.blend.name}',
            _blendTile(
              context,
              blend,
              prefix,
              keyOverride:
                  '$prefix-comp-$b-ref-$r-${blend.blend.id ?? blend.blend.name}',
            ),
          ),
    ];
  }

  /// One ref's blend uses at their realized grams, in item order.
  List<BlendLine> _refBlends(ComponentRef ref) => [
    for (final item in ref.recipe.scaledBy(ref.factor).items)
      if (item is BlendLine) item,
  ];

  String _blockLabel(RefBlock block) {
    final name = block.recipe.name;
    final suffixes = [
      if (block.count > 1) '× ${block.count}',
      if (block.factor != 1 && block.factor != block.count)
        '× ${_factorText(block.factor)}',
    ];
    return suffixes.isEmpty ? name : '$name ${suffixes.join(' · ')}';
  }

  String _factorText(double factor) =>
      factor % 1 == 0 ? factor.round().toString() : '$factor';

  /// One rendering pass per ref (`scaledBy` exactly once, so a rounding
  /// step applies with the full ref factor), summed per ingredient for
  /// display only. A part's own blend uses render as attached rows, not
  /// here; a nested ref's lines stay out of the sum.
  List<({String key, String text})> _blockRows(RefBlock block) {
    final sums = <String, ({Unit unit, double amount})>{};
    for (final ref in block.refs) {
      for (final item in ref.recipe.scaledBy(ref.factor).items) {
        if (item is! RecipeLine) continue;
        final line = item;
        final id = line.ingredient.id;
        final prev = sums[id];
        sums[id] = prev == null
            ? (unit: line.quantity.unit, amount: line.quantity.amount)
            : (
                unit: prev.unit,
                amount: prev.amount + line.quantity.amount,
              );
      }
    }
    return [
      for (final entry in sums.entries)
        (key: entry.key, text: '${quantityText(_displaySum(entry.value))} ${entry.key}'),
    ];
  }

  Quantity _displaySum(({Unit unit, double amount}) sum) {
    var quantity = Quantity(sum.amount, sum.unit);
    if (massUnit == MassUnit.oz && sum.unit.kind == UnitKind.mass) {
      quantity = quantity.convertTo(Unit.oz);
    }
    return quantity;
  }

  Widget _ruledRow(BuildContext context, String key, String text) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.rule)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: ValueKey(key),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(text, style: boxQuantity(context)),
        ),
      ),
    );
  }

  Quantity _displayQuantity(RecipeLine line) {
    final sub = subs[line.ingredient.id];
    final effective = sub == null
        ? line
        : applySubstitution(line, [sub])?.line ?? line;
    var quantity = effective.quantity;
    if (massUnit == MassUnit.oz && quantity.unit.kind == UnitKind.mass) {
      quantity = quantity.convertTo(Unit.oz);
    }
    return quantity;
  }

  Widget _lineTile(BuildContext context, RecipeLine line, String prefix) {
    final sub = subs[line.ingredient.id];
    final effective = sub == null
        ? line
        : applySubstitution(line, [sub])?.line ?? line;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).extension<BoxTokens>()!.rule,
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          key: ValueKey('$prefix-line-${line.ingredient.id}'),
          dense: true,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          onLongPress:
              sub == null &&
                  (substitutionTable[line.ingredient.id]?.isNotEmpty ?? false)
              ? () => onSubstitute(line)
              : null,
          title: Text(
            '${quantityText(_displayQuantity(line))} ${effective.ingredient.id}',
            style: boxQuantity(context),
          ),
          subtitle: sub != null && sub.note != null
              ? Text(sub.note!, style: boxAnnotation(context, size: 14))
              : null,
        ),
      ),
    );
  }

  /// Piece noun for a count-yield card: the recipe's own seed noun, else
  /// the nearest ancestor's, so a derivative of a cookies seed still
  /// reads "cookies".
  String _pieceNoun(Recipe recipe) {
    var current = recipe;
    while (true) {
      final noun = _seedPieceNouns[seedPrefixes[current.id] ?? current.id];
      if (noun != null) return noun;
      final parentId = current.parentId;
      final parent = parentId == null ? null : book.byId(parentId);
      if (parent == null) return ' pieces';
      current = parent;
    }
  }

  String _yieldText(Recipe scaled, Recipe raw) {
    final count = scaled.yield.count;
    if (count != null) {
      return 'Makes ${count.round()}${_pieceNoun(raw)}';
    }
    return 'Makes ${scaled.yield.totalGrams!.round()} g';
  }

  String _targetText(Recipe raw, double target) => raw.yield.totalGrams != null
      ? 'Target: ${target.round()} g'
      : 'Target: ${target.round()}${_pieceNoun(raw)}';

  Widget _panSection(
    BuildContext context,
    Recipe raw,
    String prefix,
    Duration baseBake,
  ) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final draft = panDraft;
    final targetPan = draft.build();
    final factor = targetPan == null
        ? null
        : panScaleFactor(_referencePan, targetPan);
    final bake = factor == null ? null : scaledBakingTime(baseBake, factor);
    final dimLabel = switch (draft.shape) {
      PanShape.round => 'diameter cm',
      PanShape.square => 'side cm',
      PanShape.rectangular => 'length cm',
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<PanShape>(
                  key: ValueKey('pan-shape-$prefix'),
                  initialValue: draft.shape,
                  isExpanded: true,
                  items: [
                    for (final shape in PanShape.values)
                      DropdownMenuItem(value: shape, child: Text(shape.name)),
                  ],
                  onChanged: (shape) {
                    draft.shape = shape!;
                    onPanChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  key: ValueKey('pan-dim-$prefix'),
                  initialValue: draft.dim1,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: boxQuantity(context),
                  decoration: InputDecoration(labelText: dimLabel),
                  onChanged: (value) {
                    draft.dim1 = value;
                    onPanChanged();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  key: ValueKey('pan-depth-$prefix'),
                  initialValue: draft.depth,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: boxQuantity(context),
                  decoration: const InputDecoration(labelText: 'depth'),
                  onChanged: (value) {
                    draft.depth = value;
                    onPanChanged();
                  },
                ),
              ),
            ],
          ),
          if (bake != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'pan factor ×${factor!.toStringAsFixed(2)} · '
                'bake ≈ ${bake.inMinutes} min (base ${baseBake.inMinutes})',
                key: ValueKey('pan-bake-$prefix'),
                style: TextStyle(fontSize: 12, color: tokens.pencil),
              ),
            ),
        ],
      ),
    );
  }
}
