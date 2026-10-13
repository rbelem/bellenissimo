import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'seed_recipes.dart';
import 'theme.dart';

final RecipeBook _seedBook = RecipeBook([
  butterCookies,
  sandwichLoaf,
  eggFreeCookies,
]);

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
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  double _cookieCount = 24;
  double _loafGrams = 900;
  String? _activeScale;

  Recipe get _scaledCookies =>
      butterCookies.scaledBy(butterCookies.factorTo(targetCount: _cookieCount));

  Recipe get _scaledLoaf => sandwichLoaf.scaledBy(
    sandwichLoaf.factorTo(targetTotalGrams: _loafGrams),
  );

  Iterable<Widget> _familyLines(Recipe recipe) sync* {
    final parentId = recipe.parentId;
    if (parentId != null) {
      yield Text(
        'variant of ${_seedBook.byId(parentId)!.name}',
        style: boxAnnotation(context),
      );
    }
    final id = recipe.id;
    if (id == null) return;
    final variants = _seedBook.derivativesOf(id);
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
            _recipeCard(
              raw: butterCookies,
              scaled: _scaledCookies,
              prefix: 'cookies',
              dragging: _activeScale == 'cookies',
              active: _activeScale == null || _activeScale == 'cookies',
              isScaled: _cookieCount.round() != 24,
              target: _cookieCount,
              min: 12,
              max: 48,
              yieldKey: 'cookies-yield',
              targetKey: 'cookies-target',
              sliderKey: 'cookies-slider',
              yieldText:
                  'Makes ${_scaledCookies.yield.count!.round()} cookies',
              targetText: 'Target: ${_cookieCount.round()} cookies',
              onChanged: (value) => setState(() => _cookieCount = value),
            ),
            const SizedBox(height: 16),
            _recipeCard(
              raw: eggFreeCookies,
              scaled: eggFreeCookies,
              prefix: 'eggfree',
              dragging: _activeScale == 'eggfree',
              active: _activeScale == null || _activeScale == 'eggfree',
              isScaled: false,
              showLines: false,
            ),
            const SizedBox(height: 16),
            _recipeCard(
              raw: sandwichLoaf,
              scaled: _scaledLoaf,
              prefix: 'loaf',
              dragging: _activeScale == 'loaf',
              active: _activeScale == null || _activeScale == 'loaf',
              isScaled: _loafGrams.round() != 900,
              target: _loafGrams,
              min: 450,
              max: 1800,
              yieldKey: 'loaf-yield',
              targetKey: 'loaf-target',
              sliderKey: 'loaf-slider',
              yieldText: 'Makes ${_scaledLoaf.yield.totalGrams!.round()} g',
              targetText: 'Target: ${_loafGrams.round()} g',
              onChanged: (value) => setState(() => _loafGrams = value),
            ),
          ],
        ),
      ),
    );
  }

  /// [raw] carries identity — name, dates, lineage, steps; [scaled] carries
  /// quantities alone, because scaledBy() returns a quantity-only projection.
  Widget _recipeCard({
    required Recipe raw,
    required Recipe scaled,
    required String prefix,
    required bool active,
    required bool isScaled,
    required bool dragging,
    bool showLines = true,
    double? target,
    double? min,
    double? max,
    String? yieldKey,
    String? targetKey,
    String? sliderKey,
    String? yieldText,
    String? targetText,
    ValueChanged<double>? onChanged,
  }) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final dated = timestampLine(raw);
    final scaleLo = min;
    final scaleHi = max;
    final scaleValue = target;
    final hasScale =
        scaleLo != null && scaleHi != null && scaleValue != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
      opacity: active ? 1 : 0.55,
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
                  if (showLines) ...[
                    const SizedBox(height: 8),
                    ..._lines(scaled, prefix),
                  ],
                  if (yieldText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _rolling(
                        yieldText,
                        Text(
                          yieldText,
                          key: ValueKey(yieldKey!),
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
                  if (hasScale) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: _rolling(
                        targetText!,
                        Text(
                          targetText,
                          key: ValueKey(targetKey!),
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
                            isScaled || dragging ? tokens.accent : tokens.rule,
                        thumbColor:
                            isScaled || dragging ? tokens.accent : tokens.pencil,
                      ),
                      child: Semantics(
                        label: 'Scale ${raw.name} yield',
                        child: Slider(
                          key: ValueKey(sliderKey!),
                          value: scaleValue,
                          min: scaleLo,
                          max: scaleHi,
                          onChanged: onChanged,
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
