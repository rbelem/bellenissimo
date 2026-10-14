import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'persistence/blend_store.dart';
import 'persistence/recipe_store.dart';
import 'recipes_page.dart';
import 'seed_recipes.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await buildApp(getApplicationSupportDirectory));
}

/// Builds the app on file stores rooted at the directory [supportDir]
/// supplies. Without usable storage the box still opens, on a seeded
/// in-memory store.
Future<Widget> buildApp(Future<Directory> Function() supportDir) async {
  try {
    final dir = await supportDir();
    final store = RecipeStore.open('${dir.path}/recipes.json');
    store.ensureSeeded(seedRecipes);
    final blends = BlendStore.open('${dir.path}/blends.json', recipes: store);
    return BellenissimosApp(store: store, blendStore: blends);
  } catch (_) {
    return const BellenissimosApp();
  }
}

class BellenissimosApp extends StatelessWidget {
  const BellenissimosApp({super.key, this.store, this.blendStore});

  final RecipeStore? store;

  final BlendStore? blendStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'bellenissimos',
    theme: recipeBoxLight,
    darkTheme: recipeBoxDark,
    home: RecipesPage(store: store, blendStore: blendStore),
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
