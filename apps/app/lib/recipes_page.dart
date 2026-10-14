import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import 'editor/recipe_editor.dart';
import 'export/box_dialog.dart';
import 'import/recipe_import_dialog.dart';
import 'blend_card.dart';
import 'persistence/blend_codec.dart';
import 'persistence/blend_store.dart';
import 'persistence/recipe_store.dart';
import 'recipe_card.dart';
import 'seed_recipes.dart';
import 'theme.dart';

/// Fallback store for tests and for launches where no database file can
/// be opened; seeded so the box is never empty.
final RecipeStore _fallbackStore = RecipeStore.inMemory()
  ..ensureSeeded(seedRecipes);

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key, this.store, this.blendStore});

  final RecipeStore? store;

  final BlendStore? blendStore;

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  late final RecipeStore _store;
  late final BlendStore _blendStore;
  late List<Recipe> _recipes;
  late RecipeBook _book;
  List<BlendRecord> _blendRecords = [];
  final Map<String, double> _targets = {};
  final Map<String, PanDraft> _pans = {};
  final Map<String, Map<String, Substitution>> _subs = {};
  MassUnit _massUnit = MassUnit.g;
  String? _activeScale;
  final ValueNotifier<String> _filter = ValueNotifier('');

  /// Sentinel marking where the blend section starts in the card list.
  final Object _blendsDivider = Object();

  List<Object> _visibleCards(String filter) {
    final query = filter.trim().toLowerCase();
    var recipes = _recipes;
    var blends = _blendRecords;
    if (query.isNotEmpty) {
      recipes = [
        for (final recipe in recipes)
          if (recipe.name.toLowerCase().contains(query) ||
              recipe.lines.any(
                (line) => line.ingredient.id.toLowerCase().contains(query),
              ))
            recipe,
      ];
      blends = [
        for (final record in blends)
          if (record.blend.name.toLowerCase().contains(query) ||
              record.blend.grams.keys.any(
                (ingredient) => ingredient.id.toLowerCase().contains(query),
              ))
            record,
      ];
    }
    return [...recipes, if (blends.isNotEmpty) _blendsDivider, ...blends];
  }

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? _fallbackStore;
    _blendStore = widget.blendStore ?? BlendStore.inMemory(_store);
    _reload();
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _reload() {
    _recipes = _store.all();
    _book = RecipeBook(_recipes);
    _blendRecords = _blendStore.all();
    for (final recipe in _recipes) {
      final base = recipe.yield.count ?? recipe.yield.totalGrams;
      if (base != null) _targets.putIfAbsent(recipe.id!, () => base);
    }
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

  void _substituteMenu(String prefix, RecipeLine line) {
    final options = substitutionTable[line.ingredient.id] ?? const [];
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
                title: Text(
                  'Replace ${line.ingredient.id} with ${option.withIngredient.id}',
                ),
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
              _massUnit == MassUnit.g ? 'oz' : 'g',
              style: const TextStyle(fontSize: 13),
            ),
            onPressed: () => setState(() {
              _massUnit = _massUnit == MassUnit.g ? MassUnit.oz : MassUnit.g;
            }),
          ),
          IconButton(
            key: const ValueKey('box-actions'),
            tooltip: 'Export or import the box',
            icon: const Icon(Icons.import_export),
            onPressed: () => showBoxDialog(
              context,
              _store,
              blends: _blendStore,
              onChanged: () => setState(_reload),
            ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: TextField(
              key: const ValueKey('recipe-filter'),
              style: boxQuantity(context),
              textInputAction: TextInputAction.search,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Find a recipe or ingredient',
              ),
              onChanged: (value) => _filter.value = value,
            ),
          ),
          Expanded(
            child: ValueListenableBuilder<String>(
              valueListenable: _filter,
              builder: (context, filter, _) {
                final visible = _visibleCards(filter);
                return visible.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No recipes match "${filter.trim()}"',
                          textAlign: TextAlign.center,
                          style: boxAnnotation(context),
                        ),
                      )
                    : _cardList(visible);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardList(List<Object> visible) => ListView.builder(
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 32),
    itemCount: visible.length,
    itemBuilder: (context, index) {
      final item = visible[index];
      return Padding(
        key: switch (item) {
          Recipe() => ValueKey(item.id),
          BlendRecord() => ValueKey('blend-${item.blend.id}'),
          _ => const ValueKey('blends-divider'),
        },
        padding: EdgeInsets.only(bottom: index == visible.length - 1 ? 0 : 16),
        child: switch (item) {
          Recipe() => _recipeCard(item),
          BlendRecord() => BlendCard(
            record: item,
            massUnit: _massUnit,
            activeScale: _activeScale,
          ),
          _ => Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'blends',
              key: const ValueKey('blends-divider-text'),
              style: boxAnnotation(context),
            ),
          ),
        },
      );
    },
  );

  Widget _recipeCard(Recipe raw) {
    final prefix = seedPrefixes[raw.id] ?? raw.id!;
    final base = raw.yield.count ?? raw.yield.totalGrams;
    return RecipeCard(
      recipe: raw,
      target: _targets[raw.id] ?? base!,
      activeScale: _activeScale,
      subs: _subs[prefix] ?? const {},
      massUnit: _massUnit,
      book: _book,
      panDraft: _pans.putIfAbsent(prefix, PanDraft.new),
      onScale: (value) => setState(() => _targets[raw.id!] = value),
      onScaleStart: () => setState(() => _activeScale = prefix),
      onScaleEnd: () => setState(() => _activeScale = null),
      onMenu: () => _cardMenu(raw),
      onSubstitute: (line) => _substituteMenu(prefix, line),
      onPanChanged: () => setState(() {}),
    );
  }
}
