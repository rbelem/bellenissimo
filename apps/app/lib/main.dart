import 'package:flutter/material.dart';

import 'recipes_page.dart';

void main() => runApp(const BellenissimosApp());

class BellenissimosApp extends StatelessWidget {
  const BellenissimosApp({super.key});

  @override
  Widget build(BuildContext context) =>
      MaterialApp(title: 'bellenissimos', home: const RecipesPage());
}
