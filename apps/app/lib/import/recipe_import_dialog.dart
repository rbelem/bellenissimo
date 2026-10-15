import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';

import '../persistence/recipe_store.dart';
import '../theme.dart';

/// Paste-a-document import: schema.org/Recipe JSON-LD in, a stored recipe
/// out. The engine collects issues instead of throwing; they surface in
/// the dialog.
class RecipeImportDialog extends StatefulWidget {
  const RecipeImportDialog({super.key, required this.store});

  final RecipeStore store;

  @override
  State<RecipeImportDialog> createState() => _RecipeImportDialogState();
}

class _RecipeImportDialogState extends State<RecipeImportDialog> {
  final _json = TextEditingController();
  List<ImportIssue> _issues = const [];

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  void _import() {
    final result = importRecipeJson(_json.text);
    if (!result.ok) {
      setState(() => _issues = result.issues);
      return;
    }
    final imported = result.recipe!;
    final now = DateTime.now();
    final id = widget.store.uniqueId(imported.name);
    final stored = Recipe(
      id: id,
      name: imported.name,
      yield: imported.yield,
      items: imported.items,
      steps: imported.steps,
      createdAt: now,
      updatedAt: now,
    );
    widget.store.upsert(stored);
    Navigator.of(context).pop(stored);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    return AlertDialog(
      title: Text('Import recipe', style: boxTitle(context, size: 19)),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('import-json'),
              controller: _json,
              maxLines: 8,
              style: boxQuantity(context, size: 12.5),
              decoration: const InputDecoration(
                labelText: 'schema.org Recipe JSON',
                alignLabelWithHint: true,
              ),
            ),
            if (_issues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final issue in _issues)
                      Text(
                        issue.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.accent,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('import-submit'),
          onPressed: _import,
          child: const Text('Import'),
        ),
      ],
    );
  }
}

/// Opens the import dialog; resolves with the stored recipe on success.
Future<Recipe?> showRecipeImportDialog(
  BuildContext context,
  RecipeStore store,
) {
  return showDialog<Recipe>(
    context: context,
    builder: (_) => RecipeImportDialog(store: store),
  );
}
