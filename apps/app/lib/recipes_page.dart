import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'persistence/recipe_store.dart';
import 'seed_recipes.dart';
import 'theme.dart';

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
  late final List<Recipe> _recipes;
  late final RecipeBook _book;
  final Map<String, double> _targets = {};
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
      yield Text(
        'variant of ${_book.byId(parentId)!.name}',
        style: boxAnnotation(context),
      );
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

  List<Widget> _lines(Recipe recipe, String prefix) => [
    for (final line in recipe.lines)
      _rolling('${line.quantity} ${line.ingredient.id}', _lineTile(line, prefix)),
  ];

  Widget _lineTile(RecipeLine line, String prefix) => Container(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).extension<BoxTokens>()!.rule),
      ),
    ),
    child: ListTile(
      key: ValueKey('$prefix-line-${line.ingredient.id}'),
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text('${line.quantity} ${line.ingredient.id}',
          style: boxQuantity(context)),
    ),
  );

  String _yieldText(Recipe scaled, String prefix) {
    final count = scaled.yield.count;
    if (count != null) {
      return 'Makes ${count.round()}${_seedPieceNouns[prefix] ?? ' pieces'}';
    }
    return 'Makes ${scaled.yield.totalGrams!.round()} g';
  }

  String _targetText(String prefix, double target) =>
      _seedPieceNouns[prefix] == null && _isMassRecipe(prefix)
          ? 'Target: ${target.round()} g'
          : 'Target: ${target.round()}${_seedPieceNouns[prefix] ?? ' pieces'}';

  bool _isMassRecipe(String prefix) => prefix == 'loaf';

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: tokens.accent),
        ),
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
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      right: raw.parentId != null ? 96 : 0,
                    ),
                    child: Text(raw.name, style: boxTitle(context)),
                  ),
                  if (dated != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
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
                  if (raw.parentId == null) ...[
                    const SizedBox(height: 8),
                    ..._lines(scaled, prefix),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _rolling(
                        _yieldText(scaled, prefix),
                        Text(
                          _yieldText(scaled, prefix),
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
                        _targetText(prefix, target),
                        Text(
                          _targetText(prefix, target),
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
                        activeTrackColor: isScaled ||
                                _activeScale == prefix
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
                          onChanged: (value) => setState(
                            () {
                              _targets[raw.id!] = value;
                            },
                          ),
                          onChangeStart: (_) =>
                              setState(() => _activeScale = prefix),
                          onChangeEnd: (_) =>
                              setState(() => _activeScale = null),
                        ),
                      ),
                    ),
                  ],
                  if (raw.steps.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
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
            if (raw.parentId != null)
              Positioned(
                top: 10,
                right: 12,
                child: Transform.rotate(
                  angle: 0.09,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.accent, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      'VARIANT',
                      style: boxStamp(context),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
