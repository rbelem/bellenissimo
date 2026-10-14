import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../persistence/recipe_store.dart';
import '../theme.dart';

/// Bottom-sheet editor for creating, editing, and deriving recipes.
class RecipeEditor extends StatefulWidget {
  const RecipeEditor({
    super.key,
    required this.store,
    this.recipe,
    this.parent,
  });

  final RecipeStore store;

  /// The recipe being edited; null creates a new one.
  final Recipe? recipe;

  /// When deriving, the recipe the new variant starts from.
  final Recipe? parent;

  @override
  State<RecipeEditor> createState() => _RecipeEditorState();
}

class _RecipeEditorState extends State<RecipeEditor> {
  late final TextEditingController _name;
  late final TextEditingController _steps;
  late final List<TextEditingController> _amounts;
  late final List<TextEditingController> _ingredients;
  late final List<Unit> _units;
  late bool _piecesMode;
  late final TextEditingController _yieldValue;

  bool get _isVariant => widget.parent != null;

  @override
  void initState() {
    super.initState();
    final source = widget.recipe ?? widget.parent;
    final initialLines = source?.lines ??
        <RecipeLine>[
          RecipeLine(seedIngredients['flour']!, const Quantity(500, Unit.g)),
        ];
    _name = TextEditingController(text: source?.name ?? '');
    _steps = TextEditingController(text: source?.steps.join('\n') ?? '');
    _amounts = [
      for (final line in initialLines)
        TextEditingController(text: _amountText(line.quantity)),
    ];
    _ingredients = [
      for (final line in initialLines)
        TextEditingController(text: line.ingredient.id),
    ];
    _units = [for (final line in initialLines) line.quantity.unit];
    final count = widget.recipe?.yield.count ?? widget.parent?.yield.count;
    final grams =
        widget.recipe?.yield.totalGrams ?? widget.parent?.yield.totalGrams;
    _piecesMode = count != null || grams == null;
    final initialValue = count ?? grams ?? (_piecesMode ? 12 : 500);
    _yieldValue = TextEditingController(
      text: _formatAmount(initialValue.toDouble()),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _steps.dispose();
    _yieldValue.dispose();
    for (final c in [..._amounts, ..._ingredients]) {
      c.dispose();
    }
    super.dispose();
  }

  String _amountText(Quantity quantity) {
    final amount = quantity.amount;
    return amount % 1 == 0 ? amount.round().toString() : '$amount';
  }

  String _formatAmount(double amount) =>
      amount % 1 == 0 ? amount.round().toString() : '$amount';

  void _addLine() => setState(() {
        _ingredients.add(TextEditingController());
        _amounts.add(TextEditingController());
        _units.add(Unit.g);
      });

  Recipe? _buildRecipe() {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final lines = <RecipeLine>[];
    for (var i = 0; i < _ingredients.length; i++) {
      final ingredientId = _ingredients[i].text.trim().toLowerCase();
      final amount = double.tryParse(_amounts[i].text.replaceAll(',', '.'));
      if (ingredientId.isEmpty || amount == null) return null;
      final seed = seedIngredients[ingredientId];
      lines.add(RecipeLine(
        seed ?? Ingredient(ingredientId),
        Quantity(amount, _units[i]),
      ));
    }
    if (lines.isEmpty) return null;
    final yieldValue = double.tryParse(_yieldValue.text.replaceAll(',', '.'));
    if (yieldValue == null || yieldValue <= 0) return null;
    final now = DateTime.now();
    final source = widget.recipe;
    return Recipe(
      id: source?.id ?? _uniqueId(name),
      parentId: source?.parentId ?? widget.parent?.id,
      name: name,
      yield: YieldSpec(
        count: _piecesMode ? yieldValue : null,
        totalGrams: _piecesMode ? null : yieldValue,
      ),
      lines: lines,
      steps: [
        for (final step in _steps.text.split('\n'))
          if (step.trim().isNotEmpty) step.trim(),
      ],
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );
  }

  String _uniqueId(String name) => widget.store.uniqueId(name);

  Future<void> _save() async {
    final recipe = _buildRecipe();
    if (recipe == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give the recipe a name and complete lines')),
      );
      return;
    }
    widget.store.upsert(recipe);
    Navigator.of(context).pop(recipe);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _isVariant ? 'New variant' : 'Recipe',
                      style: boxTitle(context, size: 21),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      key: const ValueKey('editor-name'),
                      controller: _name,
                      style: boxQuantity(context),
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SegmentedButton<bool>(
                          key: const ValueKey('editor-yield-mode'),
                          segments: const [
                            ButtonSegment(value: true, label: Text('pieces')),
                            ButtonSegment(value: false, label: Text('grams')),
                          ],
                          selected: {_piecesMode},
                          onSelectionChanged: (selection) => setState(() {
                            _piecesMode = selection.first;
                          }),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('editor-yield-value'),
                            controller: _yieldValue,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            style: boxQuantity(context),
                            decoration: const InputDecoration(
                              labelText: 'Yield',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _ingredients.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextField(
                                key: ValueKey('editor-line-ingredient-$i'),
                                controller: _ingredients[i],
                                style: boxQuantity(context),
                                decoration: InputDecoration(
                                  labelText: i == 0 ? 'Ingredient' : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                key: ValueKey('editor-line-amount-$i'),
                                controller: _amounts[i],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.,]'),
                                  ),
                                ],
                                style: boxQuantity(context),
                                decoration: const InputDecoration(
                                  labelText: 'Amount',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<Unit>(
                                key: ValueKey('editor-line-unit-$i'),
                                initialValue: _units[i],
                                isExpanded: true,
                                items: [
                                  for (final unit in Unit.values)
                                    DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit.name),
                                    ),
                                ],
                                onChanged: (unit) => setState(() {
                                  _units[i] = unit!;
                                }),
                              ),
                            ),
                            IconButton(
                              key: ValueKey('editor-line-remove-$i'),
                              icon: const Icon(Icons.remove_circle_outline),
                              tooltip: 'Remove line',
                              onPressed: _ingredients.length > 1
                                  ? () => setState(() {
                                        _ingredients.removeAt(i);
                                        _amounts.removeAt(i);
                                        _units.removeAt(i);
                                      })
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      key: const ValueKey('editor-add-line'),
                      onPressed: _addLine,
                      icon: const Icon(Icons.add),
                      label: const Text('Add ingredient'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('editor-steps'),
                      controller: _steps,
                      maxLines: 6,
                      style: boxQuantity(context),
                      decoration: const InputDecoration(
                        labelText: 'Steps (one per line)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                key: const ValueKey('editor-save'),
                onPressed: _save,
                child: const Text('Save recipe'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the editor sheet and returns the saved recipe, or null when the
/// sheet was dismissed.
Future<Recipe?> showRecipeEditor(
  BuildContext context,
  RecipeStore store, {
  Recipe? recipe,
  Recipe? parent,
}) {
  final tokens = Theme.of(context).extension<BoxTokens>()!;
  return showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (_) => RecipeEditor(store: store, recipe: recipe, parent: parent),
  );
}
