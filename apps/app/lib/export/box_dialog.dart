import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../persistence/blend_store.dart';
import '../persistence/recipe_store.dart';
import '../theme.dart';
import 'box_io.dart';

/// Opens the box sheet: export the whole box (recipes and blends) to a
/// JSON file, or import a pasted box document with replace or merge
/// semantics. [onChanged] runs after a successful import so the caller
/// can reload.
Future<void> showBoxDialog(
  BuildContext context,
  RecipeStore store, {
  required BlendStore blends,
  Future<Directory> Function()? supportDir,
  VoidCallback? onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _BoxSheet(
      store: store,
      blends: blends,
      supportDir: supportDir,
      onChanged: onChanged,
    ),
  );
}

class _BoxSheet extends StatefulWidget {
  const _BoxSheet({
    required this.store,
    required this.blends,
    this.supportDir,
    this.onChanged,
  });

  final RecipeStore store;
  final BlendStore blends;
  final Future<Directory> Function()? supportDir;
  final VoidCallback? onChanged;

  @override
  State<_BoxSheet> createState() => _BoxSheetState();
}

class _BoxSheetState extends State<_BoxSheet> {
  BoxImportMode _mode = BoxImportMode.merge;
  final _paste = TextEditingController();

  @override
  void dispose() {
    _paste.dispose();
    super.dispose();
  }

  void _report(String message) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _export() async {
    final dir = await (widget.supportDir ?? getApplicationSupportDirectory)();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/bellenissimos-box-$stamp.json');
    file.writeAsStringSync(widget.store.exportBox(widget.blends.all()));
    _report('Box exported to ${file.path.split(Platform.pathSeparator).last}');
  }

  void _import() {
    final result = widget.store.importBox(
      _paste.text,
      mode: _mode,
      blends: widget.blends,
    );
    if (result.imported == 0) {
      _report(result.issues.first.toString());
      return;
    }
    widget.onChanged?.call();
    final blends = result.blends == 0 ? '' : ' and ${result.blends} blends';
    final issues = result.issues.isEmpty
        ? ''
        : ' with issues: ${result.issues.map((issue) => issue.message).join(', ')}';
    _report('Imported ${result.imported} recipes$blends$issues');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('The whole box', style: boxTitle(context)),
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
                    FilledButton.icon(
                      key: const ValueKey('box-export'),
                      onPressed: _export,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Export box to a JSON file'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('box-paste'),
                      controller: _paste,
                      maxLines: 5,
                      style: boxQuantity(context, size: 12.5),
                      decoration: const InputDecoration(
                        labelText: 'Paste a box document to import',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<BoxImportMode>(
                      key: const ValueKey('box-mode'),
                      segments: const [
                        ButtonSegment(
                          value: BoxImportMode.merge,
                          label: Text('merge'),
                        ),
                        ButtonSegment(
                          value: BoxImportMode.replace,
                          label: Text('replace'),
                        ),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (selection) =>
                          setState(() => _mode = selection.first),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('box-import'),
                      onPressed: _import,
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Import pasted box'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
