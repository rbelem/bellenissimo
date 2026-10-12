import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'seed_recipes.dart';

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

  Recipe get _scaledLoaf => sandwichLoaf
      .scaledBy(sandwichLoaf.factorTo(targetTotalGrams: _loafGrams));

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
            Text('Butter cookies',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Makes ${_scaledCookies.yield.count!.round()} cookies',
                key: const ValueKey('cookies-yield')),
            Text('Target: ${_cookieCount.round()} cookies',
                key: const ValueKey('cookies-target')),
            Slider(
              key: const ValueKey('cookies-slider'),
              value: _cookieCount,
              min: 12,
              max: 48,
              onChanged: (value) => setState(() => _cookieCount = value),
            ),
            ..._lines(_scaledCookies, 'cookies'),
            Text('Sandwich loaf',
                style: Theme.of(context).textTheme.titleLarge),
            Text('Makes ${_scaledLoaf.yield.totalGrams!.round()} g',
                key: const ValueKey('loaf-yield')),
            Text('Target: ${_loafGrams.round()} g',
                key: const ValueKey('loaf-target')),
            Slider(
              key: const ValueKey('loaf-slider'),
              value: _loafGrams,
              min: 450,
              max: 1800,
              onChanged: (value) => setState(() => _loafGrams = value),
            ),
            ..._lines(_scaledLoaf, 'loaf'),
            ],
          ),
        ),
      );
}
