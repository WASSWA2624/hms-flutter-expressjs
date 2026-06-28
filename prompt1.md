# Frontend UI audit, consolidation, and optimization

Perform a full audit of the Flutter frontend (`frontend/lib/`) and implement fixes that improve performance, responsiveness, visual consistency, and maintainability—without changing product behavior or breaking existing flows.

## Scope

- **In scope:** `frontend/lib/` (features, shared components, layout, forms, clinical actions, l10n usage).
- **Out of scope:** Backend API changes, database/schema work, and net-new features unless required to remove duplication safely.
- **Reference library:** Existing shared components live under `frontend/lib/shared/components/` and are exported from `components.dart`. Prefer extending these over creating parallel implementations.

## Phase 1 — Discovery and inventory

Produce a written audit before making broad refactors. For each finding, note file path(s), severity, and recommended action.

### 1.1 UI performance

Identify anything that degrades runtime performance or perceived smoothness, including:

- Unnecessary rebuilds (`setState`, provider/listenable misuse, missing `const`, oversized `build()` methods).
- Heavy widgets rebuilt on every frame (lists without keys/lazy loading, unbounded `Column`/`ListView` nesting, expensive layout in item builders).
- Synchronous work on the UI thread (parsing, filtering large collections in `build`, blocking I/O).
- Missing memoization or caching where the same derived data is recomputed repeatedly.
- Large monolithic pages (e.g. workspace pages >1k lines) that hurt hot reload, navigation, and reviewability.

### 1.2 Responsiveness and layout

Review breakpoints, spacing, and overflow behavior across form factors (mobile, tablet, desktop/web):

- Inconsistent use of shared layout helpers (e.g. `responsive_spacing.dart`, toolbar overflow handling).
- Fixed sizes, hard-coded padding, or layouts that break at narrow widths.
- Dialogs, tables, and toolbars that clip, scroll incorrectly, or feel cramped on smaller viewports.

### 1.3 Component duplication and drift

Find UI patterns implemented more than once when a shared component already exists or should exist:

- Buttons, icon buttons, fields, dialogs, list rows, status chips, skeleton/loading states, empty/error views, search bars, sort menus, record sections, etc.
- Near-duplicate widgets that differ only in styling or minor layout—candidates for parameterized shared components.
- Feature-local copies of logic already in `shared/components/`, `shared/layout/`, `shared/forms/`, or `shared/clinical_actions/`.

**Goal:** Every reusable UI primitive is defined once in `shared/` (or a clearly named feature submodule if truly feature-specific). Similarity across screens is expected; copy-paste implementations are not.

### 1.4 Dead and obsolete code

Identify code that is safe to remove:

- Unused Dart files, widgets, exports, and private helpers (verify with analyzer and reference search—do not delete based on guesswork).
- Obsolete one-off migration scripts in `frontend/tool/` that have already been applied and are no longer referenced (keep `run_web_5201.ps1` and any script documented in `frontend/tool/README.md`).
- Commented-out blocks, unused imports, and unreachable branches introduced by prior migrations.

## Phase 2 — Implementation

Execute fixes in small, reviewable commits grouped by theme (performance, shared components, dead code removal).

### 2.1 Consolidation rules

- Move duplicated UI into `frontend/lib/shared/components/` (or the appropriate `shared/` submodule) and update call sites.
- Match existing naming (`app_*`), export new components from `components.dart`, and follow patterns in nearby files (e.g. `app_button.dart`, `app_dialog.dart`, `app_state_view.dart`).
- Prefer composition and parameters over subclass forests. Do not over-abstract one-off screens.
- Keep diffs minimal: refactor only what the audit flagged; avoid drive-by reformatting or unrelated renames.

### 2.2 Performance and responsiveness fixes

- Apply targeted fixes from the audit (const constructors, extract subtrees, `ListView.builder`, debounced search, split giant pages where practical).
- Ensure loading, empty, and error states use shared primitives (`app_skeleton.dart`, `app_state_view.dart`) for a uniform feel.
- Verify web and desktop layouts after changes—this app is actively run via `frontend/tool/run_web_5201.ps1`.

### 2.3 Cleanup

- Delete confirmed dead code and obsolete scripts; document any retained script’s purpose in `frontend/tool/README.md` if unclear.
- Remove unused imports and fix analyzer warnings introduced or exposed by the work.

## Phase 3 — Verification

Before finishing, run from `frontend/`:

```sh
dart format .
flutter analyze
flutter test
```

Manually smoke-test critical workspaces (auth, patient registry, at least two large workspace pages) on web at port 5201. Confirm no visual regressions, no new overflow errors, and no functional breakage.

## Deliverables

1. **Audit summary** — categorized findings (performance, responsiveness, duplication, dead code) with paths and severity.
2. **Implementation** — consolidated shared components, performance/responsiveness fixes, and removed dead code.
3. **Changelog note** — brief list of what moved to shared components and what was deleted, so future work does not reintroduce duplicates.

## Constraints

- Do not change user-visible behavior, API contracts, or routing unless fixing a clear bug.
- Do not add dependencies without strong justification.
- Do not create commits unless explicitly asked.
- Preserve accessibility semantics right-to-left compatibility where already supported.
- When two implementations differ in behavior, reconcile behavior in the shared component rather than silently dropping edge cases.

## Definition of done

- No duplicated reusable UI primitives remain without a documented reason.
- Analyzer is clean (no new errors; warnings reduced where touched).
- Tests pass.
- The app feels more uniform (consistent buttons, fields, dialogs, loading/empty states) and measurably leaner (fewer redundant widgets, fewer unnecessary rebuilds on key screens).
