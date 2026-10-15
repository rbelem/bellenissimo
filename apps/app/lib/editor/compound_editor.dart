import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../compound_math.dart';
import '../persistence/blend_store.dart';
import '../persistence/recipe_store.dart';
import '../theme.dart';

/// One component row of the draft. A row owns its controllers, so
/// add/remove/dispose touch exactly one structure.
sealed class _ComponentRow {
  List<TextEditingController> get controllers;

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

class _PartRow extends _ComponentRow {
  _PartRow({this.recipe, String pick = '', String factor = ''})
      : pick = TextEditingController(text: pick),
        factor = TextEditingController(text: factor);

  Recipe? recipe;

  final TextEditingController pick;

  final TextEditingController factor;

  @override
  List<TextEditingController> get controllers => [pick, factor];
}

class _LeafRow extends _ComponentRow {
  _LeafRow({String name = '', String amount = '', this.unit = Unit.g})
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);

  final TextEditingController name;

  final TextEditingController amount;

  Unit unit;

  @override
  List<TextEditingController> get controllers => [name, amount];
}

class _BlendRow extends _ComponentRow {
  _BlendRow({this.blend, String pick = '', String grams = ''})
      : pick = TextEditingController(text: pick),
        grams = TextEditingController(text: grams);

  Blend? blend;

  final TextEditingController pick;

  final TextEditingController grams;

  @override
  List<TextEditingController> get controllers => [pick, grams];
}

/// Bottom-sheet editor for compound dishes: parts picked from the box's
/// recipes plus bare ingredient lines, assembled in order. The sheet
/// edits the tree only; timestamps are set on save.
class CompoundEditor extends StatefulWidget {
  const CompoundEditor({super.key, required this.store, this.blends, this.recipe});

  final RecipeStore store;

  /// The blend library behind the blend picker; null or empty hides
  /// the control entirely.
  final BlendStore? blends;

  /// The compound being edited; null creates a new one.
  final Recipe? recipe;

  @override
  State<CompoundEditor> createState() => _CompoundEditorState();
}

class _CompoundEditorState extends State<CompoundEditor> {
  late final TextEditingController _name;
  late final TextEditingController _makes;
  late final List<_ComponentRow> _rows;
  late bool _piecesMode;

  Recipe? get _source => widget.recipe;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _source?.name ?? '');
    final count = _source?.yield.count;
    final grams = _source?.yield.totalGrams;
    _piecesMode = count != null || grams == null;
    _makes = TextEditingController(
      text: _format(count ?? grams ?? 1),
    );
    final items = _source?.items ?? const <RecipeItem>[];
    _rows = [
      for (final item in items)
        switch (item) {
          ComponentRef(:final recipe, :final factor) => _PartRow(
              recipe: recipe,
              pick: recipe.name,
              factor: _format(factor),
            ),
          BlendLine(:final blend, :final grams) => _BlendRow(
              blend: blend,
              pick: blend.name,
              grams: _format(grams),
            ),
          RecipeLine(:final ingredient, :final quantity) => _LeafRow(
              name: ingredient.id,
              amount: _format(quantity.amount),
              unit: quantity.unit,
            ),
        },
    ];
    _name.addListener(_rebuild);
    _makes.addListener(_rebuild);
    for (final row in _rows) {
      _listen(row);
    }
  }

  void _listen(_ComponentRow row) {
    for (final controller in row.controllers) {
      controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _makes.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _format(double amount) =>
      amount % 1 == 0 ? amount.round().toString() : '$amount';

  Future<void> _addPart() async {
    final index = _rows.length;
    final row = _PartRow();
    setState(() {
      _listen(row);
      _rows.add(row);
    });
    await _pickPart(index);
  }

  void _addLeaf() => setState(() {
        final row = _LeafRow();
        _listen(row);
        _rows.add(row);
      });

  void _addBlend() async {
    final index = _rows.length;
    final row = _BlendRow();
    setState(() {
      _listen(row);
      _rows.add(row);
    });
    await _pickBlend(index);
  }

  void _removeRow(int index) {
    final row = _rows.removeAt(index);
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
  }

  List<Recipe> get _pickable => [
        for (final recipe in widget.store.all())
          if (!recipe.isCompound && recipe.id != _source?.id) recipe,
      ];

  List<Blend> get _libraryBlends => [
    if (widget.blends != null)
      for (final record in widget.blends!.all())
        if (record.blend.id != null) record.blend,
  ];

  Future<void> _pickBlend(int index) async {
    final picked = await showModalBottomSheet<Blend>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final blend in _libraryBlends)
              ListTile(
                key: ValueKey('compound-pick-blend-${blend.id}'),
                title: Text(blend.name),
                subtitle: Text(
                  '${blend.grams.keys.map((i) => i.id).join(' + ')}'
                  ' · ${blend.totalGrams.round()} g',
                  style: boxAnnotation(context, size: 14),
                ),
                onTap: () => Navigator.of(context).pop(blend),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      final row = _rows[index] as _BlendRow;
      row.blend = picked;
      row.pick.text = picked.name;
      row.grams.text = _format(picked.totalGrams);
    });
  }

  String _yieldSummary(Recipe recipe) {
    final grams = recipe.yield.totalGrams;
    if (grams != null) return '${grams.round()} g';
    return 'makes ${recipe.yield.count!.round()}';
  }

  Future<void> _pickPart(int index) async {
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final recipe in _pickable)
              ListTile(
                key: ValueKey('compound-pick-${recipe.id}'),
                title: Text(recipe.name),
                subtitle: Text(
                  '${recipe.items.whereType<RecipeLine>().map((line) => line.ingredient.id).join(' + ')}'
                  ' · ${_yieldSummary(recipe)}',
                  style: boxAnnotation(context, size: 14),
                ),
                onTap: () => Navigator.of(context).pop(recipe),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      (_rows[index] as _PartRow)
        ..recipe = picked
        ..pick.text = picked.name;
    });
  }

  RecipeTree? _draftTree() {
    if (_rows.isEmpty) return null;
    final components = <RecipeItem>[];
    for (final row in _rows) {
      switch (row) {
        case _PartRow(:final recipe, :final factor):
          if (recipe == null) return null;
          final text = factor.text.trim();
          final parsed =
              text.isEmpty ? 1.0 : double.tryParse(text.replaceAll(',', '.'));
          if (parsed == null || parsed <= 0) return null;
          final id = recipe.id;
          final current = id == null ? null : widget.store.byId(id);
          components.add(ComponentRef(current ?? recipe, factor: parsed));
        case _BlendRow(:final blend, :final grams):
          if (blend == null) return null;
          final amount =
              double.tryParse(grams.text.replaceAll(',', '.'));
          if (amount == null || amount <= 0) return null;
          final blendId = blend.id;
          final current =
              blendId == null ? null : widget.blends?.byId(blendId)?.blend;
          components.add(BlendLine(current ?? blend, amount));
        case _LeafRow():
          final id = row.name.text.trim().toLowerCase();
          final amount =
              double.tryParse(row.amount.text.replaceAll(',', '.'));
          if (id.isEmpty || amount == null) return null;
          components.add(
            RecipeLine(
              seedIngredients[id] ?? Ingredient(id),
              Quantity(amount, row.unit),
            ),
          );
      }
    }
    return RecipeTree(name: _name.text.trim(), components: components);
  }

  String? _readoutText() {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final tree = _draftTree();
    if (tree == null) return null;
    final count = tree.components.length;
    final estimate = compoundEstimateGrams(tree.components);
    final noun = count == 1 ? 'part' : 'parts';
    if (estimate == null) return '$count $noun';
    return '$count $noun · ≈ ${(estimate / 1000).toStringAsFixed(1)} kg';
  }

  void _save() {
    final name = _name.text.trim();
    final makes = double.tryParse(_makes.text.replaceAll(',', '.'));
    final tree = _draftTree();
    if (name.isEmpty || tree == null || makes == null || makes <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the dish a name and complete rows'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final source = _source;
    final saved = Recipe.compound(
      id: source?.id ?? widget.store.uniqueId(name),
      parentId: source?.parentId,
      name: name,
      yield: YieldSpec(
        count: _piecesMode ? makes : null,
        totalGrams: _piecesMode ? null : makes,
      ),
      tree: tree,
      steps: source?.steps ?? const [],
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );
    widget.store.upsert(saved);
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final readout = _readoutText();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                      _source == null ? 'New compound dish' : 'Compound dish',
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
                          key: const ValueKey('editor-compound-yield-mode'),
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
                            key: const ValueKey('editor-compound-makes'),
                            controller: _makes,
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
                              labelText: 'Makes',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: switch (_rows[i]) {
                          _PartRow() => _partRow(context, i),
                          _BlendRow() => _blendRow(context, i),
                          _LeafRow() => _leafRow(context, i),
                        },
                      ),
                    if (_pickable.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('editor-add-part'),
                          onPressed: _addPart,
                          icon: const Icon(Icons.layers),
                          label: const Text('Add part from recipes'),
                        ),                      ),
                    if (_libraryBlends.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('editor-add-blend'),
                          onPressed: _addBlend,
                          icon: const Icon(Icons.call_merge),
                          label: const Text('Add blend'),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        key: const ValueKey('editor-add-line'),
                        onPressed: _addLeaf,
                        icon: const Icon(Icons.add),
                        label: const Text('Add ingredient line'),
                      ),
                    ),
                    if (readout != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            readout,
                            key: const ValueKey('editor-compound-readout'),
                            style: boxQuantity(
                              context,
                              size: 12.5,
                            ).copyWith(color: tokens.pencil),
                          ),
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
                child: const Text('Save dish'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partRow(BuildContext context, int i) {
    final row = _rows[i] as _PartRow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: ValueKey('editor-comp-$i-pick'),
            controller: row.pick,
            readOnly: true,
            style: boxQuantity(context),
            decoration: const InputDecoration(
              labelText: 'Part',
              hintText: 'Pick a recipe',
            ),
            onTap: () => _pickPart(i),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: ValueKey('editor-comp-$i-factor'),
            controller: row.factor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: boxQuantity(context),
            decoration: const InputDecoration(labelText: '×'),
          ),
        ),
        IconButton(
          key: ValueKey('editor-comp-$i-remove'),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove row',
          onPressed: () => _removeRow(i),
        ),
      ],
    );
  }

  Widget _blendRow(BuildContext context, int i) {
    final row = _rows[i] as _BlendRow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: ValueKey('editor-comp-$i-blend'),
            controller: row.pick,
            readOnly: true,
            style: boxQuantity(context),
            decoration: const InputDecoration(
              labelText: 'Blend',
              hintText: 'Pick a blend',
            ),
            onTap: () => _pickBlend(i),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: TextField(
            key: ValueKey('editor-comp-$i-blend-grams'),
            controller: row.grams,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: boxQuantity(context),
            decoration: const InputDecoration(labelText: 'grams'),
          ),
        ),
        IconButton(
          key: ValueKey('editor-comp-$i-remove'),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove row',
          onPressed: () => _removeRow(i),
        ),
      ],
    );
  }

  Widget _leafRow(BuildContext context, int i) {
    final row = _rows[i] as _LeafRow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            key: ValueKey('editor-comp-$i-ingredient'),
            controller: row.name,
            style: boxQuantity(context),
            decoration: const InputDecoration(labelText: 'Ingredient'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: TextField(
            key: ValueKey('editor-comp-$i-amount'),
            controller: row.amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            style: boxQuantity(context),
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: DropdownButtonFormField<Unit>(
            key: ValueKey('editor-comp-$i-unit'),
            initialValue: row.unit,
            isExpanded: true,
            items: [
              for (final unit in Unit.values)
                DropdownMenuItem(value: unit, child: Text(unit.name)),
            ],
            onChanged: (unit) => setState(() {
              row.unit = unit!;
            }),
          ),
        ),
        IconButton(
          key: ValueKey('editor-comp-$i-remove'),
          icon: const Icon(Icons.remove_circle_outline),
          tooltip: 'Remove row',
          onPressed: () => _removeRow(i),
        ),
      ],
    );
  }
}

/// Opens the compound editor sheet and returns the saved dish, or null
/// when the sheet was dismissed.
Future<Recipe?> showCompoundEditor(
  BuildContext context,
  RecipeStore store, {
  BlendStore? blends,
  Recipe? recipe,
}) {
  final tokens = Theme.of(context).extension<BoxTokens>()!;
  return showModalBottomSheet<Recipe>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (_) => CompoundEditor(store: store, blends: blends, recipe: recipe),
  );
}
