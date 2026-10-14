import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'editor/recipe_editor.dart';
import 'import/recipe_import_dialog.dart';
import 'persistence/recipe_store.dart';
import 'seed_recipes.dart';
import 'theme.dart';

/// Display unit for mass quantities.
enum _MassUnit { g, oz }

/// One target-pan draft for a card.
class _PanDraft {
  _PanDraft({
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


/// Fallback store for tests and for launches where no database file can
/// be opened; seeded so the box is never empty.
final RecipeStore _fallbackStore = RecipeStore.inMemory()..ensureSeeded(seedRecipes);

/// Stable scale-control prefixes for the seeded cards, so widget keys in
/// tests and integrations stay put. Anything new derives its prefix from
/// its id.
const _seedPrefixes = <String, String>{
  'butter-cookies': 'cookies',
  'sandwich-loaf': 'loaf',
  'egg-free-cookies': 'eggfree',
};

const _seedPieceNouns = <String, String>{'cookies': ' cookies'};

/// Built-in mass-equivalence swaps derived from seed densities, plus the
/// classic egg-free move. Users pick from these per row.
/// Built-in mass-equivalence swaps. gramsPerGram comes from the seeds'
/// densities (with.gramsPerMl / from.gramsPerMl) so both directions
/// weigh the same. Substitutions are a VIEW over a card — the source
/// recipe never changes.
final _substitutionTable = <String, List<Substitution>>{
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
String? timestampLine(Recipe recipe) {
  final created = recipe.createdAt;
  final updated = recipe.updatedAt;
  if (created == null || updated == null) return null;
  return 'created ${_ymd(created)} · updated ${_ymd(updated)}';
}

String _ymd(DateTime date) =>
    '${date.year}-${_two(date.month)}-${_two(date.day)}';

String _two(int value) => value.toString().padLeft(2, '0');

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, this.store});

  final RecipeStore? store;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  late final RecipeStore _store;
  late List<Recipe> _recipes;
  late RecipeBook _book;
  final Map<String, double> _targets = {};
  final Map<String, _PanDraft> _pans = {};
  final Map<String, Map<String, Substitution>> _subs = {};
  _MassUnit _massUnit = _MassUnit.g;
  String? _activeScale;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? _fallbackStore;
    _reload();
  }

  void _reload() {
    _recipes = _store.all();
    _book = RecipeBook(_recipes);
    for (final recipe in _recipes) {
      final base = recipe.yield.count ?? recipe.yield.totalGrams;
      if (base != null) _targets.putIfAbsent(recipe.id!, () => base);
    }
  }

  Iterable<Widget> _familyLines(Recipe recipe) sync* {
    final parentId = recipe.parentId;
    if (parentId != null) {
      final parent = _book.byId(parentId);
      if (parent != null) {
        yield Text(
          'variant of ${parent.name}',
          style: boxAnnotation(context),
        );
      }
    }
    final id = recipe.id;
    if (id == null) return;
    final variants = _book.derivativesOf(id);
    if (variants.isEmpty) return;
    yield Text(
      'variants: ${variants.map((r) => r.name).join(', ')}',
      style: boxAnnotation(context),
    );
  }

  /// In-place roll: when the text changes, the old figure slides up and away
  /// while the new one slides in from below — never a jump-cut. Under Reduce
  /// Motion the swap is an instant cut.
  Widget _rolling(String text, Widget child) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return KeyedSubtree(key: ValueKey(text), child: child);
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutExpo,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(text), child: child),
    );
  }

  List<Widget> _lines(Recipe recipe, String prefix, Map<String, Substitution> subs) => [
    for (final line in recipe.lines)
      _rolling('${_displayQuantity(line, subs)} ${line.ingredient.id}',
          _lineTile(line, prefix, subs)),
  ];

  Quantity _displayQuantity(RecipeLine line, Map<String, Substitution> subs) {
    final sub = subs[line.ingredient.id];
    final effective = sub == null ? line : applySubstitution(line, [sub])?.line ?? line;
    var quantity = effective.quantity;
    if (_massUnit == _MassUnit.oz && quantity.unit.kind == UnitKind.mass) {
      quantity = quantity.convertTo(Unit.oz);
    }
    return quantity;
  }

  String _quantityText(Quantity quantity) {
    if (quantity.unit == Unit.oz && quantity.amount % 1 != 0) {
      return '${quantity.amount.toStringAsFixed(1)} oz';
    }
    if (quantity.unit == Unit.g && quantity.amount % 1 != 0) {
      return '${quantity.amount.round()} g';
    }
    return '$quantity';
  }

  Widget _lineTile(
    RecipeLine line,
    String prefix,
    Map<String, Substitution> subs,
  ) {
    final sub = subs[line.ingredient.id];
    final effective = sub == null ? line : applySubstitution(line, [sub])?.line ?? line;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).extension<BoxTokens>()!.rule),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
        key: ValueKey('$prefix-line-${line.ingredient.id}'),
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        onLongPress: sub == null &&
                (_substitutionTable[line.ingredient.id]?.isNotEmpty ?? false)
            ? () => _substituteMenu(prefix, line)
            : null,
        title: Text(
          '${_quantityText(_displayQuantity(line, subs))} ${effective.ingredient.id}',
          style: boxQuantity(context),
        ),
        subtitle: sub != null && sub.note != null
            ? Text(
                sub.note!,
                style: boxAnnotation(context, size: 14),
              )
            : null,
      ),
      ),
    );
  }

  void _substituteMenu(String prefix, RecipeLine line) {
    final options = _substitutionTable[line.ingredient.id] ?? const [];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in options)
              ListTile(
                key: ValueKey('sub-$prefix-${option.withIngredient.id}'),
                leading: const Icon(Icons.swap_horiz),
                title: Text('Replace ${line.ingredient.id} with ${option.withIngredient.id}'),
                subtitle: option.note == null ? null : Text(option.note!),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _subs.putIfAbsent(prefix, () => {});
                    _subs[prefix]![line.ingredient.id] = option;
                  });
                },
              ),
          ],
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
      final noun = _seedPieceNouns[_seedPrefixes[current.id] ?? current.id];
      if (noun != null) return noun;
      final parentId = current.parentId;
      final parent = parentId == null ? null : _book.byId(parentId);
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

  Widget _panSection(Recipe raw, String prefix, Duration baseBake) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final draft = _pans.putIfAbsent(prefix, _PanDraft.new);
    final targetPan = draft.build();
    final factor = targetPan == null ? null : panScaleFactor(_referencePan, targetPan);
    final bake =
        factor == null ? null : scaledBakingTime(baseBake, factor);
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
                  onChanged: (shape) => setState(() => draft.shape = shape!),
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
                  onChanged: (value) => setState(() => draft.dim1 = value),
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
                  onChanged: (value) => setState(() => draft.depth = value),
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

  Future<void> _addRecipe() async {
    final saved = await showRecipeEditor(context, _store);
    if (saved != null) setState(_reload);
  }

  Future<void> _importRecipe() async {
    final saved = await showRecipeImportDialog(context, _store);
    if (saved != null) setState(_reload);
  }

  Future<void> _editRecipe(Recipe raw) async {
    final saved = await showRecipeEditor(context, _store, recipe: raw);
    if (saved != null) setState(_reload);
  }

  Future<void> _newVariant(Recipe raw) async {
    final saved = await showRecipeEditor(context, _store, parent: raw);
    if (saved != null) setState(_reload);
  }

  Future<void> _deleteRecipe(Recipe raw) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${raw.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).extension<BoxTokens>()!.accent,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      _store.delete(raw.id!);
      setState(_reload);
    }
  }

  void _cardMenu(Recipe raw) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: ValueKey('menu-variant-${raw.id}'),
              leading: const Icon(Icons.call_split),
              title: Text('Save a variant of ${raw.name}'),
              onTap: () {
                Navigator.of(context).pop();
                _newVariant(raw);
              },
            ),
            ListTile(
              key: ValueKey('menu-edit-${raw.id}'),
              leading: const Icon(Icons.edit_outlined),
              title: Text('Edit ${raw.name}'),
              onTap: () {
                Navigator.of(context).pop();
                _editRecipe(raw);
              },
            ),
            ListTile(
              key: ValueKey('menu-delete-${raw.id}'),
              leading: const Icon(Icons.delete_outline),
              title: Text('Delete ${raw.name}'),
              onTap: () {
                Navigator.of(context).pop();
                _deleteRecipe(raw);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          IconButton(
            key: const ValueKey('toggle-mass-unit'),
            tooltip: 'Toggle mass unit',
            icon: Text(
              _massUnit == _MassUnit.g ? 'oz' : 'g',
              style: const TextStyle(fontSize: 13),
            ),
            onPressed: () => setState(() {
              _massUnit =
                  _massUnit == _MassUnit.g ? _MassUnit.oz : _MassUnit.g;
            }),
          ),
          IconButton(
            key: const ValueKey('import-recipe'),
            tooltip: 'Import recipe JSON',
            icon: const Icon(Icons.paste),
            onPressed: _importRecipe,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: tokens.accent),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const ValueKey('add-recipe'),
        onPressed: _addRecipe,
        child: const Icon(Icons.add),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < _recipes.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _recipeCard(_recipes[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _recipeCard(Recipe raw) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final prefix = _seedPrefixes[raw.id] ?? raw.id!;
    final base = raw.yield.count ?? raw.yield.totalGrams;
    final target = _targets[raw.id] ?? base!;
    final isScaled = target != base;
    final scaled = raw.scaledBy(target / base!);
    final dated = timestampLine(raw);
    final scaleLo = base / 2;
    final scaleHi = base * 2;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      opacity: _activeScale == null || _activeScale == prefix ? 1 : 0.55,
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
                    onPressed: () => _cardMenu(raw),
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
              ..._familyLines(raw),
              const SizedBox(height: 8),
              ..._lines(scaled, prefix, _subs[prefix] ?? const {}),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _rolling(
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
                child: _rolling(
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
                  activeTrackColor:
                      isScaled || _activeScale == prefix
                          ? tokens.accent
                          : tokens.rule,
                  thumbColor: isScaled || _activeScale == prefix
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
                    onChanged: (value) =>
                        setState(() => _targets[raw.id!] = value),
                    onChangeStart: (_) =>
                        setState(() => _activeScale = prefix),
                    onChangeEnd: (_) => setState(() => _activeScale = null),
                  ),
                ),
              ),
              if (_baseBakeTime(raw) != null)
                _panSection(raw, prefix, _baseBakeTime(raw)!),
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
}
