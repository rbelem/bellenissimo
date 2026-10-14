import 'package:bellenissimos_app/main.dart' as app;
import 'package:bellenissimos_app/persistence/blend_codec.dart';
import 'package:bellenissimos_app/persistence/blend_store.dart';
import 'package:bellenissimos_app/persistence/recipe_store.dart';
import 'package:bellenissimos_app/seed_recipes.dart';
import 'package:bellenissimos_core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BlendRecord _eryXyl() => BlendRecord(
  blend: SweetenerBlend(
    id: 'ery-xyl',
    name: 'Erythritol xylitol',
    grams: {
      const Ingredient('erythritol'): 100,
      const Ingredient('xylitol'): 100,
    },
    sweetnessPerGram: {
      const Ingredient('erythritol'): 0.7,
      const Ingredient('xylitol'): 1.0,
    },
  ),
);

/// 140 g erythritol + 60 g sugar lands at ×0.79 — losesBulk.
BlendRecord _weak() => BlendRecord(
  blend: SweetenerBlend(
    id: 'weak-swap',
    name: 'Half sugar swap',
    grams: {const Ingredient('erythritol'): 140, const Ingredient('sugar'): 60},
    sweetnessPerGram: {
      const Ingredient('erythritol'): 0.7,
      const Ingredient('sugar'): 1.0,
    },
  ),
);

Recipe _recipeWith(Blend blend, {double grams = 120}) => butterCookies.copyWith(
  id: 'blend-cookies',
  blends: [BlendLine(blend, grams)],
);

void main() {
  setUpAll(() {
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestWidgetsFlutterBinding.ensureInitialized();
    TestWidgetsFlutterBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channel.name, (message) async {
          return const StandardMessageCodec().encodeMessage(
            '/tmp/opencode/bellenissimos-test',
          );
        });
  });

  late RecipeStore store;
  late BlendStore blends;

  Future<void> pumpApp(
    WidgetTester tester, {
    bool seedBlends = true,
    Recipe? extraRecipe,
  }) async {
    tester.view.physicalSize = const Size(1170, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    store = RecipeStore.inMemory()..ensureSeeded(seedRecipes);
    if (extraRecipe != null) store.upsert(extraRecipe);
    blends = BlendStore.inMemory(store);
    if (seedBlends) blends.upsertAll([_eryXyl(), _weak()]);
    await tester.pumpWidget(
      app.BellenissimosApp(store: store, blendStore: blends),
    );
    await tester.pumpAndSettle();
  }

  Future<void> editButterCookies(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('menu-butter-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-butter-cookies')));
    await tester.pumpAndSettle();
  }

  testWidgets('attaches a blend from the editor with grams prefilled', (
    tester,
  ) async {
    await pumpApp(tester);
    await editButterCookies(tester);

    expect(find.byKey(const ValueKey('editor-attach-blend')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('editor-attach-blend')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('attach-blend-ery-xyl')), findsOneWidget);
    expect(find.text('erythritol + xylitol · 200 g'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('attach-blend-ery-xyl')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('editor-attached-grams-0')),
          )
          .controller!
          .text,
      '200',
    );

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final saved = store.byId('butter-cookies')!;
    expect(saved.blends.single.grams, 200);
    expect(saved.blends.single.blend.id, 'ery-xyl');
  });

  testWidgets('the attach control hides when the library is empty', (
    tester,
  ) async {
    await pumpApp(tester, seedBlends: false);
    await editButterCookies(tester);

    expect(find.byKey(const ValueKey('editor-attach-blend')), findsNothing);
  });

  testWidgets('an attached row can be removed before saving', (tester) async {
    await pumpApp(tester);
    await editButterCookies(tester);
    await tester.tap(find.byKey(const ValueKey('editor-attach-blend')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('attach-blend-ery-xyl')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editor-attached-remove-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('editor-attached-grams-0')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    expect(store.byId('butter-cookies')!.blends, isEmpty);
  });

  testWidgets('saving the editor picks up blend edits made meanwhile', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));

    await tester.tap(find.byKey(const ValueKey('menu-blend-cookies')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-edit-blend-cookies')));
    await tester.pumpAndSettle();

    final renamed = BlendRecord(
      blend: SweetenerBlend(
        id: 'ery-xyl',
        name: 'Ery xyl v2',
        grams: {
          const Ingredient('erythritol'): 150,
          const Ingredient('xylitol'): 50,
        },
        sweetnessPerGram: {
          const Ingredient('erythritol'): 0.7,
          const Ingredient('xylitol'): 1.0,
        },
      ),
    );
    blends.upsertBlend(renamed);

    await tester.tap(find.byKey(const ValueKey('editor-save')));
    await tester.pumpAndSettle();

    final line = store.byId('blend-cookies')!.blends.single;
    expect(line.grams, 120);
    expect(line.blend.name, 'Ery xyl v2');
  });

  testWidgets('an attached blend renders collapsed and expands in place', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));

    final row = find.byKey(const ValueKey('blend-cookies-line-ery-xyl'));
    expect(row, findsOneWidget);
    expect(
      (tester.widget<ListTile>(row).title as Text).data,
      '120 g Erythritol xylitol',
    );
    expect(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-part-erythritol')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('60 g erythritol'), findsOneWidget);
    expect(find.text('60 g xylitol'), findsOneWidget);
    expect(find.text('sweetness of ≈ 102 g sugar'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('60 g erythritol'), findsNothing);
  });

  testWidgets('blend rows scale with the slider, parts ride the scaled line', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));

    tester
        .widget<Slider>(find.byKey(const ValueKey('blend-cookies-slider')))
        .onChanged!(36);
    await tester.pumpAndSettle();

    expect(
      (tester
                  .widget<ListTile>(
                    find.byKey(const ValueKey('blend-cookies-line-ery-xyl')),
                  )
                  .title
              as Text)
          .data,
      '180 g Erythritol xylitol',
    );

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('90 g erythritol'), findsOneWidget);
    expect(find.text('sweetness of ≈ 153 g sugar'), findsOneWidget);
  });

  testWidgets('the bulk note shows at the point of use for a weak blend', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_weak().blend, grams: 100));

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-weak-swap-toggle')),
    );
    await tester.pumpAndSettle();

    expect(find.text('sweetness of ≈ 79 g sugar'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blend-cookies-line-weak-swap-bulk-note')),
      findsOneWidget,
    );
  });

  testWidgets('the mass toggle reaches blend rows, not the sugar equivalent', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));

    await tester.tap(find.byKey(const ValueKey('toggle-mass-unit')));
    await tester.pumpAndSettle();

    expect(
      (tester
                  .widget<ListTile>(
                    find.byKey(const ValueKey('blend-cookies-line-ery-xyl')),
                  )
                  .title
              as Text)
          .data,
      '4.2 oz Erythritol xylitol',
    );

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('2.1 oz erythritol'), findsOneWidget);
    expect(find.text('sweetness of ≈ 102 g sugar'), findsOneWidget);
  });

  testWidgets('a blend deleted from the library keeps rendering from the '
      'recipe copy', (tester) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));
    blends.delete('ery-xyl');
    await tester.pumpAndSettle();

    expect(blends.byId('ery-xyl'), isNull);
    expect(
      (tester
                  .widget<ListTile>(
                    find.byKey(const ValueKey('blend-cookies-line-ery-xyl')),
                  )
                  .title
              as Text)
          .data,
      '120 g Erythritol xylitol',
    );

    await tester.tap(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl-toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('60 g erythritol'), findsOneWidget);
  });

  testWidgets('a blend row offers no substitution on long-press', (
    tester,
  ) async {
    await pumpApp(tester, extraRecipe: _recipeWith(_eryXyl().blend));

    await tester.longPress(
      find.byKey(const ValueKey('blend-cookies-line-ery-xyl')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replace erythritol with oil'), findsNothing);
    expect(find.byType(ListTile), findsWidgets);
  });
}
