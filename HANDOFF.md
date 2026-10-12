# Bellenissimos — Handoff

Updated: 2026-10-12 · HEAD `6fd7a93` on `main` · working tree clean

## What this is

Flutter recipes app (Play Store + App Store target) for cakes, breads, pies.
The product moat is a **correct scaling engine**, not CRUD: kitchen units,
density bridges, yield-dimension scaling, pan volumes, ingredient rounding
roles, blends, substitutions. Everything else serves that engine.

## Repo map

```
pubspec.yaml            root (intentionally NOT a pub workspace — see Gotchas)
packages/core/          pure-Dart engine, zero Flutter deps, 100% lcov enforced
  lib/src/unit.dart          Unit/UnitKind (g kg oz lb | ml l tsp tbsp cup flOz | piece)
  lib/src/quantity.dart      convertTo / bridgedTo / gramsOf / millilitresOf / scaledBy / roundedToNearest
  lib/src/ingredient.dart    id, gramsPerMl, gramsPerPiece, roundingStep (half eggs)
  lib/src/recipe.dart        Recipe (id, parentId, steps, createdAt/updatedAt, copyWith), RecipeLine, YieldSpec
  lib/src/recipe_book.dart   byId / derivativesOf (parent links via parentId, never mutated)
  lib/src/recipe_tree.dart   ComponentLeaf/ComponentRef, scaledBy, replaceRecipe, layeredCake
  lib/src/pan.dart           Pan (round/square/rect), panScaleFactor, scaledBakingTime (documented heuristic)
  lib/src/blend.dart         SweetenerBlend (sucrose-equivalent, losesBulk), FlourMix (protein %, hydration)
  lib/src/substitution.dart  applySubstitution (mass-equivalence, piece-aware output)
  lib/src/recipe_import.dart schema.org/Recipe JSON-LD → Recipe, issue-collecting, never throws
  lib/src/seeds.dart         approximate cup-weight table (240 ml US cup), user-overridable by design
apps/app/               Flutter shell (android/ios/linux/web), path dep ../../packages/core
flake.nix               linux-desktop dev shell (flutter, gtk3, cmake, ninja, clang, pkg-config)
devbox.json             dart, flutter, gtk3, cmake, ninja, clang, pkg-config + scripts
```

## Commands

| What | How |
|---|---|
| Core tests | `devbox run test` |
| App tests | `devbox run test:app` |
| Coverage gate (both packages, 100% lines) | `devbox run coverage` — fails on ANY uncovered line |
| Analyze | `devbox run -- bash -c "cd packages/core && dart analyze"` |
| Desktop with hot reload | `nix develop .#linux-desktop -c bash -c 'cd apps/app && flutter run -d linux'` (needs a real TTY) |
| Desktop quick run (no reload) | `apps/app/build/linux/x64/debug/bundle/bellenissimos_app` (390×844 phone window) |
| Web | `cd apps/app && flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8123` |

## Engine invariants (do not break)

- Canonical units are grams / ml / pieces. Volume↔mass needs `gramsPerMl`;
  count↔mass needs `gramsPerPiece`; both needed for pieces↔volume.
- Recipes are immutable. Scaling returns new instances; original untouched.
- **Single-rounding rule**: ingredient `roundingStep` (e.g. half eggs) applies
  ONCE with the full compound factor. RecipeTree scales ComponentRefs by
  `ref.factor * treeFactor` in one pass — never chain two `scaledBy` calls.
- `YieldSpec` dimensions are `count` and/or `totalGrams`; `factorTo` takes
  exactly one target and throws on zero or two.
- Derivatives: child sets `parentId`; listing is computed via `RecipeBook`
  (parents are never mutated). `replaceRecipe(originalId, replacement)` swaps
  refs inside trees, factors preserved.
- Timestamps are caller-set data; the engine never infers times.
- Seeds are approximations by design; the UI must let users override.

## Conventions

- TDD red→green, public seams only, no mocks needed (pure functions, no I/O).
- 100% line coverage is a hard gate. If a line can't be covered by a
  meaningful test, delete the line (no dead code, no impossible-state guards).
- `lints/recommended`, analyzer clean, complexity ≤ 10 per function.
- No comments except non-obvious domain whys (heuristics, single-rounding).
- Parallel work = cow worktrees (`spawn_workspace`), disjoint file ownership,
  each lane pushes `feat-*`, gates green before push, merge + gate after each.
- Conventional Commits.

## Gotchas (paid for already — don't relearn)

1. App→core path dep is `../../packages/core`. `../packages/core` resolves to
   `apps/packages/core`, and pub's error says "doesn't exist" — misleading.
2. **No pub workspace** on purpose: core (dart pub) and app (flutter pub)
   resolve independently; a shared workspace couples `flutter_test`'s pinned
   `test_api` with core's `test` and breaks version solving.
3. `flutter create --platforms web .` resurrects the template
   `test/widget_test.dart` (references `MyApp`) — delete it; real tests are in
   `app_test.dart`. Its compile error also crashes the shared compiler and
   masks as unrelated failures.
4. Linux build flaking? Move `apps/app/build` to /tmp and rebuild. Known
   failures: cmake install to `/usr/local` (stale cache) and missing
   `build/native_assets/linux` (recreated by a clean build).
5. `flutter run` without a TTY kills the app after launch ("Lost connection").
   Launch the built bundle with `setsid … &` for a persistent window, or run
   inside the flake shell from a real terminal.
6. Browser MCP: flatpak Firefox needs `--marionette --new-instance --profile`;
   flatpak Chrome screenshots write into the sandbox FS, not the host.
7. GDK/Pango "font file not found" warnings in the desktop app are cosmetic
   (GTK decorations only); Flutter content uses bundled fonts.

## Current state

- 159 tests (core 152, app 7) · analyzer clean · 100% lcov both packages
- Engine: units, conversions, seeds, yield scaling, rounding, pans, trees,
  layered cakes, replacements, blends, substitutions, JSON import (steps)
- App: recipe list with live scaling sliders, steps, variant/parent lines,
  timestamps; a seeded egg-free derivative demonstrates the family links
- Desktop window build verified; web server currently OFF

## Next steps, priority order

1. **Persistence** — Drift/SQLite for recipes. Seeds are hardcoded in
   `apps/app/lib/seed_recipes.dart`; this is the biggest missing spine.
2. Recipe editor UI (create/edit/delete; bump `updatedAt` via `copyWith`).
3. Pan adaptation in the UI — engine already provides `panScaleFactor` +
   `scaledBakingTime`; nothing in the UI uses them yet.
4. Import fidelity: `HowToSection` → named step groups (currently an issue).
5. Leavening sub-linear scaling (role-based scaling rules in the engine).
6. Sweetener/flour blend UI on top of the blend engine.
7. Sync — needs a product decision: Supabase vs Firebase vs JSON export first.
8. Store release plumbing: icons, splash, signing, listings.
