# Workspace Toolbar — Responsive Label Rules

## Objective

Standardize **workspace header and toolbar** responsive behavior across all HOSSPI HMS modules. Screen titles and primary actions must adapt by breakpoint so mobile stays compact, tablet shows readable titles, and desktop shows full labeled actions — without per-page overrides.

**Reference UI:** Patient registry at `/patients` (screenshots: ~302px, ~390px, ~649px, desktop).

---

## Responsive rules

Use existing breakpoints from `frontend/lib/core/responsive/app_breakpoints.dart`:


| Breakpoint              | Width     | Screen title (icon + label) | Primary action (icon + label) | Secondary / overflow actions                    |
| ----------------------- | --------- | --------------------------- | ----------------------------- | ----------------------------------------------- |
| **Mobile** (`xs`, `sm`) | < 600px   | Icon only — hide title text | Icon only                     | Icon + label; overflow via ⋮ menu               |
| **Tablet** (`md`)       | 600–839px | Icon + label                | Icon only                     | Icon + label; overflow via ⋮ menu               |
| **Large** (`lg`+)       | ≥ 840px   | Icon + label                | Icon + label                  | Labels where space allows; overflow when needed |




### Visual target (Patient registry)

- **Mobile:** Leading module icon visible; no “Patient registry” text; **Add patient** shown as icon-only (or pinned inline icon when space allows).
- **Tablet (~649px):** “Patient registry” title visible; **Add patient** remains icon-only.
- **Desktop:** “Patient registry” title visible; **Add patient** shows icon **and** label.

Accessibility: when text is hidden, preserve `Semantics` / tooltips so icon-only controls remain discoverable.

---



## Scope

Apply **globally** in shared layout components — not in individual feature pages.


| Area                  | File                                                         | Change                                                                                        |
| --------------------- | ------------------------------------------------------------ | --------------------------------------------------------------------------------------------- |
| Toolbar action labels | `frontend/lib/shared/layout/app_workspace_toolbar.dart`      | Drive `AppActionLabelScope.showLabels` from breakpoint: icon-only below `lg`; labels at `lg+` |
| Workspace title text  | `frontend/lib/shared/layout/app_workspace.dart`              | Keep title text hidden at `xs`/`sm` via `hidesWorkspaceTitle`; show from `md` upward          |
| Breakpoint helpers    | `frontend/lib/core/responsive/app_breakpoints.dart`          | Add a named helper (e.g. `showsToolbarActionLabels`) if it clarifies intent                   |
| Label scope           | `frontend/lib/shared/components/app_action_label_scope.dart` | No API change expected — consume updated scope values                                         |


**Out of scope:** App shell header (HOSSPI logo bar), filter bar, list/table layout, page-specific toolbar action definitions.

---



## Current vs desired


| Behavior                        | Current                                 | Desired              |
| ------------------------------- | --------------------------------------- | -------------------- |
| Title text on mobile            | Hidden at `xs`/`sm` ✓                   | Unchanged            |
| Title text on tablet            | Shown at `md` ✓                         | Unchanged            |
| Toolbar labels on tablet        | Shown from `md` ✗                       | Icon-only until `lg` |
| Toolbar labels on desktop       | Shown from `md`                         | Shown from `lg`      |
| Primary pinned inline on mobile | Primary stays inline, others overflow ✓ | Unchanged            |


---



## Acceptance criteria

- [ ] At widths < 600px, workspace shows module icon only (no title text) and toolbar primary action is icon-only.
- [ ] At 600–839px, workspace title text is visible; toolbar primary (and secondary) actions remain icon-only.
- [ ] At ≥ 840px, toolbar primary action shows icon + label (e.g. “Add patient”).
- [ ] Behavior is consistent on Patient registry, OPD, and at least one other workspace using `appWorkspaceToolbarWithLabels`.
- [ ] Icon-only controls retain accessible names (semantics and/or tooltips).
- [ ] `flutter analyze` and `frontend/test/shared/layout/app_workspace_toolbar_test.dart` pass; add/update breakpoint coverage if needed.

---



## Quality gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/layout/app_workspace_toolbar_test.dart
```

