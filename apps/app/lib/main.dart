import 'package:flutter/material.dart';

import 'recipes_page.dart';
import 'theme.dart';

void main() => runApp(const BellenissimosApp());

class BellenissimosApp extends StatelessWidget {
  const BellenissimosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'bellenissimos',
        theme: recipeBoxLight,
        darkTheme: recipeBoxDark,
        home: const RecipesPage(),
        // Desktop runs in a phone-shaped window; even if maximized, the
        // content stays a centered mobile column.
        builder: (context, child) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      );
}
