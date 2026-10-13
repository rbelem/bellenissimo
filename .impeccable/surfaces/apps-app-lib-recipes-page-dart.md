---
version: 1
slug: "apps-app-lib-recipes-page-dart"
primary_target: "apps/app/lib/recipes_page.dart"
related_targets: []
---

# Surface brief — recipes list (apps/app/lib/recipes_page.dart)

Scope: the app's first screen (recipe list). Visitor mode: Operate.
Audience: home bakers and small-batch pros; job: read and rescale a recipe's quantities at a glance mid-bake; action: move the scale control and trust the recomputed column; constraints: app tests pin exact copy ('Makes 24 cookies', '250 g flour', 'Target: 36 cookies', numbered steps, family lines, timestamps) and widget keys; no dead controls may ship.

## Direction contract

THESIS: every recipe is an index card in one family box — the scaling engine lives on the card, and a derivative is an annotated copy stamped VARIANT, never a re-typed recipe. Refuses the category's photo-feed card and the bare utility list alike.

OWN-WORLD: walnut box ground #3E2F23, card-stock cream #F7F2E9, ink #2B2118, stamp red #C03B2E reserved for variant stamps and changed quantities, pencil #8A8072 for annotations and dates. Type: Zilla Slab for card titles, Courier Prime for every quantity (measurement, not costume), Caveat for lineage annotations, system sans for body. Density: ruled card rows, one spacing rhythm; shadows carry offset and blur like stacked cards.

STORY: the baker opens one box; each card shows its ruled quantity column and its own scale control; moving a control rolls the numbers in place and lights the changed yield in stamp red; a stamped VARIANT card carries its lineage in pencil. Nothing else pretends to exist: no dead nav, no dead FAB.

FIRST VIEWPORT: walnut box interior; lid bar 'Recipes' set in Zilla Slab over a 2px stamp-red rule; Butter cookies card full attention — title, date line in pencil, four ruled quantity rows in Courier Prime, 'Makes 36 cookies' red-underlined when scaled, scale slider 24→36 on the card; egg-free card below with rotated VARIANT stamp and Caveat lineage note; loaf card beginning at the fold.

FORM: the assigned direction, seed key 6b8aa06f. Carries three raises: rolling numerals (from the split-flap board) as the one authored motion — AnimatedSwitcher in-place roll on quantities, never a jump-cut; focus-and-recede (from the streaming wall) — while a card's slider is dragged, sibling cards dim to half presence; one reversed plate (from the slide rack) is RESERVED for a future step/bake context, not this screen. Light scheme chosen by scene: a lit kitchen; a dark espresso scheme ships as first-class sibling.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.
