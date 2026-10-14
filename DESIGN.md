---
name: bellenissimos
description: Recipe-scaling app for cakes, breads, and pies — every recipe an index card in one family box.
colors:
  walnut: "#3E2F23"
  espresso: "#241B14"
  card-cream: "#F7F2E9"
  card-espresso: "#35291E"
  ink: "#2B2118"
  cream-ink: "#F1E9DA"
  stamp-red: "#C03B2E"
  stamp-red-dark: "#E06A55"
  pencil: "#6E6252"
  pencil-dark: "#B3A48D"
  rule: "#E2D8C4"
  rule-dark: "#4A3B2C"
typography:
  title:
    fontFamily: "ZillaSlab"
    fontSize: "19px"
    fontWeight: 600
    lineHeight: 1.25
  quantity:
    fontFamily: "CourierPrime"
    fontSize: "14.5px"
    fontWeight: 400
    lineHeight: 1.3
  yield:
    fontFamily: "CourierPrime"
    fontSize: "15.5px"
    fontWeight: 700
    lineHeight: 1.3
  annotation:
    fontFamily: "Caveat"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.25
  label:
    fontFamily: "system-ui"
    fontSize: "10.5px"
    fontWeight: 400
    letterSpacing: "1.2px"
  body:
    fontFamily: "system-ui"
    fontSize: "13.5px"
    fontWeight: 400
    lineHeight: 1.45
rounded:
  card: "4px"
spacing:
  xs: "3px"
  sm: "8px"
  md: "12px"
  lg: "16px"
components:
  recipe-card:
    backgroundColor: "{colors.card-cream}"
    textColor: "{colors.ink}"
    rounded: "{rounded.card}"
  yield-line-changed:
    backgroundColor: "transparent"
    textColor: "{colors.stamp-red}"
  quantity-row:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
  blend-readout:
    backgroundColor: "transparent"
    textColor: "{colors.pencil}"
  fab:
    backgroundColor: "{colors.card-cream}"
    textColor: "{colors.walnut}"
    rounded: "12px"
  editor-save:
    backgroundColor: "{colors.card-cream}"
    textColor: "{colors.walnut}"
    rounded: "4px"
---

# Design System: bellenissimos

## Overview

**Creative North Star: "The Recipe Box"**

Every recipe is an index card in one family box. The app is a walnut card box holding cream stock: titles are typed in a workmanlike slab, quantities are measurement type, lineage is penciled in handwriting, and a derivative is an annotated copy — same card as any other, its lineage penciled in, never re-typed from scratch. The world lends warmth and material; it never supplies navigation or controls, which stay standard Material 3.

Density is ruled-card density: hairline rules every row, one spacing rhythm, no ornaments between the baker and the next number. The aesthetic philosophy is precision without intimidation — pro-grade formula discipline served on home-kitchen card stock.

**Key Characteristics:**
- Walnut ground, cream card faces, one red reserved for meaning
- Quantities always in monospace measurement type, never decorative
- Stacked-card shadows with offset and blur, like cards resting on cards
- Lineage (variants, parents) in handwriting, never in system chrome
- No dead controls: every visible control works

## Colors

A warm paper-and-timber palette where red is scarce and therefore loud.

### Primary
- **Stamp Red** (#C03B2E): the accent — the changed-yield underline, the lid rule under the app bar, destructive confirms, and slider accents only while scaled or dragged. Its rarity is the point. Dark scheme lightens it to #E06A55 for contrast.

### Neutral
- **Walnut** (#3E2F23): the box interior — scaffold ground and app bar in the light scheme; deepens to **Espresso** (#241B14) in dark.
- **Card Cream** (#F7F2E9): every card face in light; **Card Espresso** (#35291E) in dark.
- **Ink** (#2B2118): titles, quantities, steps on cream; **Cream Ink** (#F1E9DA) on espresso.
- **Pencil** (#6E6252): dates, target labels, idle slider thumbs — everything secondary is pencil, never gray; **Pencil Dark** (#B3A48D) in dark.
- **Rule** (#E2D8C4): 1px hairlines under every quantity row, inactive slider track; **Rule Dark** (#4A3B2C) in dark.

### Named Rules
**The Red Reservation Rule.** Stamp red appears only where it carries meaning: a changed yield line, the 2px lid rule, destructive confirms, and slider accents while scaled or dragged. It never decorates. An idle slider is pencil on rule, not red.

**The No Gray Rule.** Secondary text is tinted pencil (warm, hue-derived), never pure gray, on both cream and espresso.

## Typography

**Title Font:** Zilla Slab SemiBold (600), self-hosted
**Quantity Font:** Courier Prime (400/700), self-hosted
**Annotation Font:** Caveat (400), self-hosted
**Body Font:** system-ui (platform voice: Roboto/SF)

**Character:** a typewritten recipe card annotated by hand — the slab carries names, the typewriter face carries every number, the handwriting carries family history.

### Hierarchy
- **Title** (600, 19px): card and screen headings.
- **Yield** (700, 15.5px): the "Makes N …" line; the only bold-red-underlined text when scaled.
- **Quantity** (400, 14.5px): every ruled ingredient row.
- **Annotation** (400, 17px): lineage lines — "variant of …", "variants: …".
- **Label** (400, 10.5px, +1.2px tracking): timestamps and target labels.
- **Body** (400, 13.5px, 1.45 line height): numbered steps.

### Named Rules
**The Measurement Voice Rule.** Courier Prime is welded to measurement. Numbers live in the typewriter face; no other element may use it, and no quantity may appear in the system sans.

**The Two-Hand Rule.** Names are typed (slab), family history is handwritten (Caveat). A piece of text gets one voice, decided by what it is, not where it sits.

## Layout

One centered mobile column, max width 480px, on every surface — the desktop dev window is phone-shaped by design. Cards stack vertically with 16px gaps; card interiors use a 16/14px padding with a single vertical rhythm (3px meta offsets, 8px group breaks, 12px before the yield line). Section order on the home screen: butter cookies → egg-free variant → loaf at the fold.

## Elevation & Depth

Cards rest on the box like stacked stock: every card carries a soft offset shadow (0 3px 10px rgba(36, 23, 16, 0.32)) — offset and blur, never a flat halo. Inside a card, depth is flat: hairline rules separate rows, and hierarchy comes from type voice, not elevation.

## Shapes

Card corners 4px — nearly square, like real index cards. Row separators are 1px hairlines. Nothing else rounds; pill shapes and large radii belong to other worlds.

## Components

### Recipe Card
- **Shape:** 4px radius, cream face (light) / espresso face (dark)
- **Background:** {colors.card-cream} / {colors.card-espresso}
- **Shadow Strategy:** stacked-card, offset+blur, one shadow per card
- **Internal Padding:** 16px horizontal, 14px vertical
- **Order inside:** title (slab) → date (label, pencil) → lineage (Caveat) → ruled quantity rows → yield line → target label + slider → numbered steps

### Quantity Row
- **Style:** full-width ListTile-height row, name and amount in Courier, 1px rule underneath
- **Behavior:** when its value changes, the row content rolls in place (old figure slides up and fades, new slides in from below, 180ms easeOutExpo); under Reduce Motion it swaps instantly

### Yield Line
- **Style:** Courier 700 15.5px
- **State:** at rest, ink/cream-ink; when the recipe is scaled from its base, stamp red with a 2px red underline — the red underline is reserved for this

### Scale Slider
- **Style:** 4px track; idle = rule track with pencil thumb; scaled or actively dragged = accent track and thumb
- **A11y:** wrapped in a Semantics label ("Scale <recipe> yield")
- **Behavior:** while dragged, sibling cards dim to 55% opacity (200ms; instant under Reduce Motion)

### Variant Card
- **Rule:** a variant renders exactly like any other recipe card — ruled quantity rows, yield line, scale slider, pan section. There is no stamp and no special chrome.
- **Difference:** the Caveat lineage note under the title ("variant of Butter cookies") is the only marker of derivation; any card, variant included, can spawn another variant from its card menu.

### Lineage Note
- **Style:** Caveat 17px, pencil — "variant of Butter cookies", "variants: …"
- **Rule:** lineage is handwriting; it never appears in system chrome

### Editor Sheet
- **Shape:** bottom sheet, 4px top radius, card face, 88% height
- **Fields:** name (Courier input), pieces/grams SegmentedButton (selected = rule fill, onCard text), ingredient rows (name + amount + unit dropdown + remove), steps one-per-line
- **Custom ingredient scaling:** a line whose ingredient is not a seed gains a "scales ×" field on a row of its own — Courier, optional; empty is linear, 0.7 behaves like yeast. The pencil hint shows only while a custom line exists
- **Save:** pinned below the scroll view — always visible; card-stock button (onSurface fill, ground text)
- **Primary actions are card stock.** The FAB and Save render in the surface color with ground-colored content — never red. Red stays reserved.

### Import Dialog
- **Shape:** M3 dialog on card face
- **Field:** multiline JSON input in Courier 12.5px
- **Issues:** engine import issues listed in stamp red under the field
- **Buttons:** Cancel (pencil), Import (card stock)

### Pan Section
- **Where:** below the scale slider on scalable recipes whose steps state a bake time
- **Controls:** shape dropdown, dimension + depth numeric fields (Courier)
- **Readout:** pencil annotation — "pan factor ×1.44 · bake ≈ 16 min (base 12)" — recomputed live from `panScaleFactor` + `scaledBakingTime` against the 20 cm reference tin

### Blend Card
- **What:** a sweetener blend or flour mix — reference stock in the same box, filed after the recipes under one Caveat pencil divider ("blends")
- **Shape:** same card as a recipe — 4px radius, card face, stacked-card shadow — with no slider and no target line: a blend is a ratio, not a batch
- **Order inside:** title (slab) → date (label, pencil) → kind line (Caveat pencil — "sweetener blend" / "flour mix") → ruled composition rows → total line (Courier 700, never red) → derived readouts → replace-sugar field (sweetener cards only)
- **Composition rows:** ruled quantity rows in Courier, grams (oz under the mass toggle); they do not scale, so they do not roll
- **Readouts:** Courier 12.5 pencil — "sweetness ×0.85 of sugar"; "protein 11.2 %" and "bread hydration ≈ 64 %"
- **Weak blend:** a blend under 0.8× sugar carries a penciled Caveat note — "won't bulk like sugar — structure will shift". It earns no red: weakness is a property of the card, not a state
- **Replace-sugar field:** the blend card's one working control — Courier numeric input ("sugar g") with a live Courier result that rolls on change, computed by the engine's replaceSugar

### Blend Editor Sheet
- **Shape:** the editor sheet — bottom sheet, 4px top radius, card face, 88% height, pinned card-stock Save
- **Kind:** chosen from the add sheet (Recipe / Sweetener blend / Flour mix / Compound dish) and fixed for the sheet's life
- **Fields:** name (Courier), composition rows of ingredient + grams + attribute — sweetness × for sweeteners, protein % for flours; no unit dropdown (blends are gram ratios)
- **Attributes:** prefilled from the seed table on a name match (sugar 1, erythritol 0.7, stevia 250; flour 10, bread 13, whole wheat 14), always overridable; unknowns default to the anchor (sweetness 1, protein 10)
- **Readout:** the computed sweetness / protein / hydration line recomposes live in Courier pencil as rows fill — approximations stay visible at authoring time

### Attached Blend Row
- **Rule:** a recipe line that references a blend renders as one ordinary ruled row — "<scaled g> <blend name>" in Courier — with a pencil expand chevron; it scales with the slider like any line
- **Expanded:** component rows indent 16px in ink Courier 13.5 with hairline rules, grams recomputed in one pass from the scaled line total; a sweetener blend adds a pencil "sweetness of ≈ N g sugar" line, and the weak-blend Caveat note when it applies
- **Scope:** expansion is a view, never persisted; a deleted blend's rows render from the recipe's own copy of the blend, so nothing dangles

### Compound Card
- **What:** a dish assembled from parts — a layered cake of two batters, fillings, a topping — filed among the recipe cards, under no divider: a compound is a recipe that yields
- **Shape:** the recipe card — 4px radius, card face, stacked-card shadow, scale slider, target line; a compound scales like any recipe, in one pass
- **Order inside:** title (slab) → date (label, pencil) → lineage (Caveat) → part blocks in assembly order → total line (Courier 700) → yield line → target label + slider → numbered steps
- **Part block:** a Caveat pencil part label carrying the part recipe's name ("batter A"), followed by that part's ruled Courier lines; consecutive references to the same recipe collapse into one counted block ("sponge × 3"); a part factor other than ×1 shows in pencil beside the label ("× 0.75")
- **Component lines:** ruled quantity rows in Courier that roll on scale like any row; bare ingredient parts render as ordinary lines inside their block
- **Total line:** the dish summed in grams, never red — size is a property, not a change
- **Rule:** a compound renders from its own tree snapshot; a deleted part recipe's rows render from the card's copy, so nothing dangles

### Compound Editor Sheet
- **Shape:** the editor sheet — bottom sheet, 4px top radius, card face, 88% height, pinned card-stock Save
- **Kind:** chosen from the add sheet (Recipe / Sweetener blend / Flour mix / Compound dish) and fixed for the sheet's life
- **Fields:** name (Courier input), a makes-N count field, then component rows in assembly order — a part row is a recipe picker + a Courier "×" factor field (empty is ×1) + remove; an ingredient row reuses the recipe line editor fields (name + amount + unit + remove)
- **Add controls:** two pencil buttons — "Add part from recipes" and "Add ingredient line"
- **Readout:** a live Courier pencil line under the rows — "4 parts · ≈ 1.9 kg" — recomputing as rows and factors change; approximations stay visible at authoring time
- **Rule:** the sheet edits the tree only; timestamps are set on save, never while previewing

### Substitution Rows
- **Trigger:** long-press a quantity row whose ingredient has a swap in the built-in seed-density table
- **Result:** the row shows the replacement ingredient and amount, with the swap's note in Caveat underneath
- **Scope:** substitutions are a view, never persisted into the source recipe

### Mass Unit Toggle
- **Style:** app-bar text button reading the unit it switches TO ("oz" / "g")
- **Effect:** mass quantities re-render in ounces (one decimal); volume and counts untouched

### Recipe Filter
- **Where:** pinned under the lid rule, above the card stack; it does not scroll away
- **Style:** single-line TextField in Courier, search icon prefix, hint "Find a recipe"
- **Behavior:** case-insensitive substring match on the recipe name and on compound part names, applied as you type; the list below builds lazily so a box of a thousand cards stays smooth
- **Empty state:** pencil annotation "No cards match …" when nothing matches (the box holds recipes and blends)

## Do's and Don'ts

### Do:
- **Do** keep stamp red for changed yields, the lid rule, and destructive confirms — nothing else.
- **Do** set every quantity in Courier Prime with tabular alignment.
- **Do** render lineage (variant/parent relations) in Caveat pencil.
- **Do** let approximations stay visible: seeds are offered, never imposed.
- **Do** honor Reduce Motion: instant swaps instead of rolls and fades.
- **Do** pin primary actions (Save) outside scrollable content — always reachable.
- **Do** keep blend cards free of red — a weak sweetener blend is a pencil note, not an alarm.

### Don't:
- **Don't** ship food photography as layout structure — the box holds cards, not a photo feed.
- **Don't** introduce a second accent color; the system has red and it is scarce.
- **Don't** put a kicker or eyebrow label above a heading.
- **Don't** set recipe identity data (steps, dates, lineage) from a scaled recipe instance — those come from the raw card; only quantities scale.
- **Don't** persist a substitution into the source recipe; swaps are a view over the card.
- **Don't** give a blend card a scale slider or target line — a blend is a ratio, not a batch.
