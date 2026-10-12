import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'seed_recipes.dart';

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

  Recipe get _scaledCookies =>
      butterCookies.scaledBy(butterCookies.factorTo(targetCount: _cookieCount));

  Recipe get _scaledLoaf => sandwichLoaf.scaledBy(
    sandwichLoaf.factorTo(targetTotalGrams: _loafGrams),
  );

  List<Widget> _header(Recipe recipe) {
    final stamped = timestampLine(recipe);
    return [
      Text(recipe.name, style: Theme.of(context).textTheme.titleLarge),
      ..._familyLines(recipe),
      if (stamped != null) Text(stamped),
      for (var i = 0; i < recipe.steps.length; i++)
        Text('${i + 1}. ${recipe.steps[i]}'),
    ];
  }

  Iterable<Widget> _familyLines(Recipe recipe) sync* {
    final parentId = recipe.parentId;
    if (parentId != null) {
      yield Text('variant of ${_seedBook.byId(parentId)!.name}');
    }
    final id = recipe.id;
    if (id == null) return;
    final variants = _seedBook.derivativesOf(id);
    if (variants.isEmpty) return;
    yield Text('variants: ${variants.map((r) => r.name).join(', ')}');
  }

  List<Widget> _lines(Recipe recipe, String prefix) => [
    for (final line in recipe.lines)
      ListTile(
        key: ValueKey('$prefix-line-${line.ingredient.id}'),
        title: Text('${line.quantity} ${line.ingredient.id}'),
      ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Recipes')),
    body: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._header(butterCookies),
          Text(
            'Makes ${_scaledCookies.yield.count!.round()} cookies',
            key: const ValueKey('cookies-yield'),
          ),
          Text(
            'Target: ${_cookieCount.round()} cookies',
            key: const ValueKey('cookies-target'),
          ),
          Slider(
            key: const ValueKey('cookies-slider'),
            value: _cookieCount,
            min: 12,
            max: 48,
            onChanged: (value) => setState(() => _cookieCount = value),
          ),
          ..._lines(_scaledCookies, 'cookies'),
          ..._header(sandwichLoaf),
          Text(
            'Makes ${_scaledLoaf.yield.totalGrams!.round()} g',
            key: const ValueKey('loaf-yield'),
          ),
          Text(
            'Target: ${_loafGrams.round()} g',
            key: const ValueKey('loaf-target'),
          ),
          Slider(
            key: const ValueKey('loaf-slider'),
            value: _loafGrams,
            min: 450,
            max: 1800,
            onChanged: (value) => setState(() => _loafGrams = value),
          ),
          ..._lines(_scaledLoaf, 'loaf'),
          ..._header(eggFreeCookies),
        ],
      ),
    ),
  );
}
