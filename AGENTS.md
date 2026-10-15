# bellenissimos

Flutter recipes app (Play Store + App Store target) for cakes, breads and
pies. The product is a correct scaling engine; everything else serves it.
Start here, then follow the pointers.

## Read next

- `PRODUCT.md` — users, purpose, scope. Read before feature work.
- `DESIGN.md` — normative design contract ("The Recipe Box"). The UI must
  match it. `.impeccable/design.json` is a snapshot of the same contract;
  update it in the same commit whenever DESIGN.md changes.
- `packages/core/` — pure-Dart engine, zero Flutter deps, 100% line-coverage
  gate. `apps/app/` — Flutter shell over a JSON-file store with seed
  migration and an in-memory fallback.

## Gates

Scripts live in `devbox.json`; all must pass before push. CI runs analyze
and tests on every push and PR.

- `devbox run test` — engine tests
- `devbox run test:app` — app widget tests (also writes apps/app/coverage)
- `devbox run analyze` / `devbox run analyze:app` — analyzer, both packages
- `devbox run coverage` — fails on ANY uncovered line in packages/core
- `devbox run run:desktop` / `run:web` / `run:reload` — manual runs

## Engine invariants (do not break)

- Canonical units are grams / ml / pieces. Volume<->mass needs `gramsPerMl`;
  count<->mass needs `gramsPerPiece`; both are needed for pieces<->volume.
- Recipes are immutable. Scaling returns new instances; the original is
  untouched.
- Single-rounding rule: ingredient `roundingStep` (half eggs) applies ONCE
  with the full compound factor. `RecipeTree.scaledBy` only accumulates the
  ref factor (snapshot untouched); the one `scaledBy` pass happens at
  realization (`recipe.scaledBy(ref.factor)`), and `replaceRecipe` swaps
  stay magnitude-preserving.
- Unified items: a recipe holds one ordered `items` list (ingredient
  lines, blend uses, recipe refs). `isCompound` derives from holding a
  ref; the box is at version 4 (v1-v3 still decode).
- `YieldSpec.factorTo` takes exactly one target and throws on zero or two.
- Derivatives: a child sets `parentId`; listing is computed via `RecipeBook`
  (parents are never mutated). `replaceRecipe(originalId, replacement)`
  swaps refs inside trees, factors preserved.
- Timestamps are caller-set data; the engine never infers times.
- Seeds are approximations by design; the UI must let users override them.

## Conventions

- TDD red->green, public seams only; pure functions mean no mocks.
- 100% line coverage is a hard gate in core. A line that cannot be covered
  by a meaningful test is deleted, not guarded.
- `lints/recommended`, analyzer clean, complexity <= 10 per function.
- No comments except non-obvious domain whys.
- Conventional Commits.

## Parallel lanes

- Fan out with cow worktrees (`spawn_workspace`), one writer per worktree,
  disjoint file ownership.
- A session that finds a git tip it did not create stands down and reports;
  it never writes over a foreign commit.
- Lanes commit in small Conventional Commits, push only their own `feat-*`
  branch, and run every gate before push. The integrator merges one lane at
  a time and re-runs the gates after each merge.

## Gotchas (paid for already — don't relearn)

- App->core path dep is `../../packages/core`. `../packages/core` resolves
  to `apps/packages/core`, and pub's error says "doesn't exist" —
  misleading.
- No pub workspace on purpose: core (dart pub) and app (flutter pub) resolve
  independently; a shared workspace couples flutter_test's pinned test_api
  with core's test and breaks version solving.
- `flutter create --platforms web .` resurrects the template
  `test/widget_test.dart` (references `MyApp`) — delete it; its compile
  error crashes the shared compiler and masks as unrelated failures.
- Linux build flaking? Move `apps/app/build` to /tmp and rebuild.
- `flutter run` without a TTY kills the app after launch ("Lost
  connection"). Launch the built bundle with `setsid ... &` for a
  persistent window.
- Widget tests over the card list: the default 800x600 surface builds only
  the visible cards of the lazy `ListView`. Set `tester.view` for whole-box
  counts, and scope Scrollable finds to the ListView, or the filter field's
  internal Scrollable matches first.
- `testWidgets` runs the body under FakeAsync: real async I/O (createTemp,
  plugin futures, network) never completes and the test hangs. Use the
  `*Sync` variants or inject fakes through a constructor parameter.
- Never pipe a gate through `tail` inside an `&&` chain: the chain sees
  tail's exit status, not the gate's, and a red run reads as green. Capture
  to a file, or run the gate bare and read its output after.
- GDK/Pango "font file not found" warnings in the desktop app are cosmetic
  (GTK decorations only); Flutter content uses bundled fonts.
