import 'package:bellenissimos_core/core.dart';

import 'recipe_codec.dart';

/// One row of the blend library: the engine blend value plus the
/// caller-set timestamps the card's date line renders.
class BlendRecord {
  const BlendRecord({required this.blend, this.createdAt, this.updatedAt});

  final Blend blend;

  final DateTime? createdAt;

  final DateTime? updatedAt;
}

/// JSON mapping between engine blends and their persisted form.
///
/// A blend doc is self-contained: every part inlines its ingredient's
/// conversion fields exactly like a recipe line does, and the per-gram
/// attribute (sweetness relative to sugar, or protein percent) rides the
/// part. The top-level `grams` is the composition total for external
/// readers; decoding recomputes from the parts.
abstract final class BlendCodec {
  static Map<String, Object?> encode(
    Blend blend, {
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => {
    'id': blend.id,
    'name': blend.name,
    'kind': _kind(blend),
    'grams': blend.totalGrams,
    'createdAt': createdAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt?.millisecondsSinceEpoch,
    'parts': [
      for (final entry in blend.grams.entries)
        {
          'ingredient': entry.key.id,
          ...RecipeCodec.ingredientFields(entry.key),
          'grams': entry.value,
          'attribute': _attribute(blend, entry.key),
        },
    ],
  };

  static BlendRecord decode(Map<String, Object?> doc) {
    final parts = [
      for (final part in doc['parts']! as List<Object?>)
        _part(part! as Map<String, Object?>),
    ];
    return BlendRecord(
      blend: switch (doc['kind']) {
        'sweetener' => SweetenerBlend(
          id: doc['id'] as String?,
          name: doc['name']! as String,
          grams: {for (final p in parts) p.ingredient: p.grams},
          sweetnessPerGram: {for (final p in parts) p.ingredient: p.attribute},
        ),
        'flour' => FlourMix(
          id: doc['id'] as String?,
          name: doc['name']! as String,
          grams: {for (final p in parts) p.ingredient: p.grams},
          proteinPct: {for (final p in parts) p.ingredient: p.attribute},
        ),
        final kind => throw ArgumentError('Unknown blend kind "$kind"'),
      },
      createdAt: RecipeCodec.millisFromDoc(doc['createdAt']),
      updatedAt: RecipeCodec.millisFromDoc(doc['updatedAt']),
    );
  }

  static Map<String, Object?> encodeLine(BlendLine line) => {
    'blend': encode(line.blend),
    'grams': line.grams,
  };

  static BlendLine decodeLine(Map<String, Object?> doc) => BlendLine(
    decode(doc['blend']! as Map<String, Object?>).blend,
    (doc['grams']! as num).toDouble(),
  );

  static String _kind(Blend blend) => switch (blend) {
    SweetenerBlend() => 'sweetener',
    FlourMix() => 'flour',
  };

  static double _attribute(Blend blend, Ingredient ingredient) =>
      switch (blend) {
        SweetenerBlend(:final sweetnessPerGram) =>
          sweetnessPerGram[ingredient]!,
        FlourMix(:final proteinPcts) => proteinPcts[ingredient]!,
      };

  static ({Ingredient ingredient, double grams, double attribute}) _part(
    Map<String, Object?> doc,
  ) => (
    ingredient: RecipeCodec.ingredientFromDoc(
      doc['ingredient']! as String,
      doc,
    ),
    grams: (doc['grams']! as num).toDouble(),
    attribute: (doc['attribute']! as num).toDouble(),
  );
}
