import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'persistence/blend_codec.dart';
import 'recipe_card.dart';
import 'rolling.dart';
import 'theme.dart';

/// One blend card: a ratio, not a batch — composition rows, derived
/// readouts, and (for sweeteners) the one working control, the
/// replace-sugar field. No slider, no target line, no red at rest.
class BlendCard extends StatefulWidget {
  const BlendCard({
    super.key,
    required this.record,
    required this.massUnit,
    required this.activeScale,
  });

  final BlendRecord record;

  final MassUnit massUnit;

  /// Scale prefix of the card being dragged, if any; blend cards dim
  /// whenever any recipe slider drags.
  final String? activeScale;

  @override
  State<BlendCard> createState() => _BlendCardState();
}

class _BlendCardState extends State<BlendCard> {
  final TextEditingController _sugar = TextEditingController();

  Blend get _blend => widget.record.blend;

  String get _id => _blend.id!;

  @override
  void dispose() {
    _sugar.dispose();
    super.dispose();
  }

  Quantity _display(double grams) {
    final quantity = Quantity(grams, Unit.g);
    return widget.massUnit == MassUnit.oz
        ? quantity.convertTo(Unit.oz)
        : quantity;
  }

  String? _replacementText() {
    final blend = _blend as SweetenerBlend;
    final value = double.tryParse(_sugar.text.replaceAll(',', '.'));
    if (value == null) return null;
    final unit = widget.massUnit == MassUnit.oz ? Unit.oz : Unit.g;
    final replacement = blend.replaceSugar(
      Quantity(value, unit),
      sugarInfo: seedIngredients['sugar']!,
    );
    return '→ ${replacement.amount.round()} g';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BoxTokens>()!;
    final blend = _blend;
    final dated = dateLine(widget.record.createdAt, widget.record.updatedAt);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final readout = boxQuantity(
      context,
      size: 12.5,
    ).copyWith(color: tokens.pencil);
    return AnimatedOpacity(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      opacity: widget.activeScale == null ? 1 : 0.55,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.card,
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              offset: Offset(0, 3),
              blurRadius: 10,
              color: Color(0x52241710),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 8),
                child: Text(blend.name, style: boxTitle(context)),
              ),
              if (dated != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      dated,
                      style: TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        color: tokens.pencil,
                      ),
                    ),
                  ),
                ),
              Text(switch (blend) {
                SweetenerBlend() => 'sweetener blend',
                FlourMix() => 'flour mix',
              }, style: boxAnnotation(context)),
              for (final entry in blend.grams.entries)
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: tokens.rule)),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      key: ValueKey('blend-$_id-line-${entry.key.id}'),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        '${quantityText(_display(entry.value))} '
                        '${entry.key.id}',
                        style: boxQuantity(context),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Total ${quantityText(_display(blend.totalGrams))}',
                  key: ValueKey('blend-$_id-total'),
                  style: boxQuantity(
                    context,
                    size: 15.5,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (blend is SweetenerBlend)
                      Text(
                        'sweetness '
                        '×${blend.sucroseEquivalentPerGram.toStringAsFixed(2)} '
                        'of sugar',
                        key: ValueKey('blend-$_id-sweetness'),
                        style: readout,
                      ),
                    if (blend is FlourMix) ...[
                      Text(
                        'protein ${blend.proteinPct.toStringAsFixed(1)} %',
                        key: ValueKey('blend-$_id-protein'),
                        style: readout,
                      ),
                      Text(
                        'bread hydration '
                        '≈ ${blend.breadHydrationPct().round()} %',
                        key: ValueKey('blend-$_id-hydration'),
                        style: readout,
                      ),
                    ],
                    if (blend is SweetenerBlend && blend.losesBulk)
                      Text(
                        "won't bulk like sugar — structure will shift",
                        key: ValueKey('blend-$_id-bulk-note'),
                        style: boxAnnotation(context, size: 14),
                      ),
                  ],
                ),
              ),
              if (blend is SweetenerBlend) _replaceSugar(context, blend),
            ],
          ),
        ),
      ),
    );
  }

  Widget _replaceSugar(BuildContext context, SweetenerBlend blend) {
    final result = _replacementText();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Semantics(
              label: 'Sugar to replace with ${blend.name}',
              child: TextField(
                key: ValueKey('blend-$_id-sugar-input'),
                controller: _sugar,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: boxQuantity(context),
                decoration: InputDecoration(
                  labelText: widget.massUnit == MassUnit.oz
                      ? 'sugar oz'
                      : 'sugar g',
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (result != null)
            rollIn(
              context,
              result,
              Text(
                result,
                key: ValueKey('blend-$_id-sugar-result'),
                style: boxQuantity(context),
              ),
            ),
        ],
      ),
    );
  }
}
