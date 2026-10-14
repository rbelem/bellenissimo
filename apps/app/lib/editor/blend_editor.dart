import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../persistence/blend_codec.dart';
import '../persistence/blend_store.dart';
import '../theme.dart';

/// Which attribute column a blend edits; fixed for the sheet's life.
enum BlendKind { sweetener, flour }

/// Sweetness relative to sugar per known ingredient — app-side seed
/// data like the substitution table, offered and overridable.
const _sweetnessSeeds = <String, double>{
  'sugar': 1.0,
  'brown_sugar': 1.0,
  'honey': 1.1,
  'xylitol': 1.0,
  'erythritol': 0.7,
  'allulose': 0.7,
  'stevia': 250,
  'monk_fruit': 200,
  'sucralose': 600,
};

/// Protein percent per known flour, straight off the bag's label.
const _proteinSeeds = <String, double>{
  'flour': 10,
  'bread_flour': 13,
  'whole_wheat_flour': 14,
  'cake_flour': 8,
};

/// Bottom-sheet editor for creating and editing blends. Kind is chosen
/// at creation time from the add sheet and never toggles mid-edit.
class BlendEditor extends StatefulWidget {
  const BlendEditor({
    super.key,
    required this.store,
    required this.kind,
    this.record,
  });

  final BlendStore store;

  final BlendKind kind;

  /// The blend being edited; null creates a new one.
  final BlendRecord? record;

  @override
  State<BlendEditor> createState() => _BlendEditorState();
}

class _BlendEditorState extends State<BlendEditor> {
  late final TextEditingController _name;
  late final List<TextEditingController> _ingredients;
  late final List<TextEditingController> _amounts;
  late final List<TextEditingController> _attributes;

  bool get _isSweetener => widget.kind == BlendKind.sweetener;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    final source = widget.record?.blend;
    final parts =
        source?.grams.entries.toList() ?? <MapEntry<Ingredient, double>>[];
    _name = TextEditingController(text: source?.name ?? '');
    _ingredients = [
      for (final part in parts) TextEditingController(text: part.key.id),
      if (parts.isEmpty) TextEditingController(),
    ];
    _amounts = [
      for (final part in parts)
        TextEditingController(text: _format(part.value)),
      if (parts.isEmpty) TextEditingController(),
    ];
    _attributes = [
      for (final part in parts)
        TextEditingController(text: _format(_attributeOf(source!, part.key))),
      if (parts.isEmpty) TextEditingController(),
    ];
    for (final controller in _ingredients) {
      _listenIngredient(controller);
    }
    _name.addListener(_rebuild);
    for (final controller in [..._amounts, ..._attributes]) {
      controller.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  /// Map iteration order is not typed; read the attribute through the
  /// blend's own per-gram map so edits restore exactly what was stored.
  double _attributeOf(Blend blend, Ingredient ingredient) => switch (blend) {
    SweetenerBlend(:final sweetnessPerGram) => sweetnessPerGram[ingredient]!,
    FlourMix(:final proteinPcts) => proteinPcts[ingredient]!,
  };

  @override
  void dispose() {
    _name.dispose();
    for (final controller in [..._ingredients, ..._amounts, ..._attributes]) {
      controller.dispose();
    }
    super.dispose();
  }

  String _format(double value) =>
      value % 1 == 0 ? value.round().toString() : '$value';

  double _seedAttribute(String id) =>
      _isSweetener ? (_sweetnessSeeds[id] ?? 1.0) : (_proteinSeeds[id] ?? 10.0);

  void _listenIngredient(TextEditingController controller) {
    controller.addListener(() {
      final index = _ingredients.indexOf(controller);
      if (index != -1) _prefillAttribute(index);
    });
  }

  /// Prefill on a name match while the attribute stands empty — seeds
  /// are approximations, never locks.
  void _prefillAttribute(int index) {
    if (_attributes[index].text.isNotEmpty) return;
    final id = _ingredients[index].text.trim().toLowerCase();
    if (id.isEmpty) return;
    _attributes[index].text = _format(_seedAttribute(id));
  }

  void _addLine() => setState(() {
    final ingredient = TextEditingController();
    _listenIngredient(ingredient);
    _ingredients.add(ingredient);
    final amount = TextEditingController();
    amount.addListener(_rebuild);
    _amounts.add(amount);
    final attribute = TextEditingController();
    attribute.addListener(_rebuild);
    _attributes.add(attribute);
  });

  Blend? _draft(String? id) {
    final name = _name.text.trim();
    if (name.isEmpty) return null;
    final grams = <Ingredient, double>{};
    final attributes = <Ingredient, double>{};
    for (var i = 0; i < _ingredients.length; i++) {
      final idText = _ingredients[i].text.trim().toLowerCase();
      final amount = double.tryParse(_amounts[i].text.replaceAll(',', '.'));
      final attribute = double.tryParse(
        _attributes[i].text.replaceAll(',', '.'),
      );
      final valid = switch (widget.kind) {
        BlendKind.sweetener => attribute != null && attribute > 0,
        BlendKind.flour => attribute != null && attribute >= 0,
      };
      final ingredient = seedIngredients[idText] ?? Ingredient(idText);
      if (idText.isEmpty ||
          amount == null ||
          amount <= 0 ||
          !valid ||
          grams.containsKey(ingredient)) {
        return null;
      }
      grams[ingredient] = amount;
      attributes[ingredient] = attribute!;
    }
    return switch (widget.kind) {
      BlendKind.sweetener => SweetenerBlend(
        id: id,
        name: name,
        grams: grams,
        sweetnessPerGram: attributes,
      ),
      BlendKind.flour => FlourMix(
        id: id,
        name: name,
        grams: grams,
        proteinPct: attributes,
      ),
    };
  }

  String _readoutText(Blend draft) => switch (draft) {
    SweetenerBlend(:final sucroseEquivalentPerGram) =>
      'sweetness ×${sucroseEquivalentPerGram.toStringAsFixed(2)} of sugar'
          ' · replaces 100 g sugar with '
          '${(100 / sucroseEquivalentPerGram).round()} g',
    FlourMix f =>
      'protein ${f.proteinPct.toStringAsFixed(1)} %'
          ' · bread hydration ≈ ${f.breadHydrationPct().round()} %',
  };

  void _save() {
    final source = widget.record;
    final name = _name.text.trim();
    final id = source?.blend.id ?? widget.store.uniqueId(name);
    final draft = _draft(id);
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give the blend a name and complete lines'),
        ),
      );
      return;
    }
    final now = DateTime.now();
    final saved = BlendRecord(
      blend: draft,
      createdAt: source?.createdAt ?? now,
      updatedAt: now,
    );
    widget.store.upsertBlend(saved);
    Navigator.of(context).pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final draft = _draft(null);
    final title = switch (widget.kind) {
      BlendKind.sweetener =>
        _isEdit ? 'Sweetener blend' : 'New sweetener blend',
      BlendKind.flour => _isEdit ? 'Flour mix' : 'New flour mix',
    };
    final attributeLabel = _isSweetener ? 'sweetness ×' : 'protein %';
    final helper = _isSweetener
        ? 'sugar is 1 · erythritol ≈ 0.7 · stevia ≈ 250'
        : "g protein per 100 g — it is on the bag's label";
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
                    child: Text(title, style: boxTitle(context, size: 21)),
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
                              flex: 2,
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
                                  labelText: 'grams',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: TextField(
                                key: ValueKey('editor-line-attribute-$i'),
                                controller: _attributes[i],
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
                                decoration: InputDecoration(
                                  labelText: attributeLabel,
                                ),
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
                                      _attributes.removeAt(i);
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
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: TextStyle(fontSize: 12, color: tokens.pencil),
                    ),
                    const SizedBox(height: 8),
                    if (draft != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _readoutText(draft),
                              key: const ValueKey('editor-blend-readout'),
                              style: boxQuantity(
                                context,
                                size: 12.5,
                              ).copyWith(color: tokens.pencil),
                            ),
                            if (draft is SweetenerBlend && draft.losesBulk)
                              Text(
                                "won't bulk like sugar — structure will shift",
                                style: boxAnnotation(context, size: 14),
                              ),
                          ],
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
                child: const Text('Save blend'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens the blend editor sheet and returns the saved record, or null
/// when the sheet was dismissed.
Future<BlendRecord?> showBlendEditor(
  BuildContext context,
  BlendStore store, {
  required BlendKind kind,
  BlendRecord? record,
}) {
  final tokens = Theme.of(context).extension<BoxTokens>()!;
  return showModalBottomSheet<BlendRecord>(
    context: context,
    isScrollControlled: true,
    backgroundColor: tokens.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
    ),
    builder: (_) => BlendEditor(store: store, kind: kind, record: record),
  );
}
