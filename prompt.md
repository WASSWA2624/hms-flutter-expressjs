# Patient Registry — Responsive Toolbar Fix

## Objective

Fix responsive layout for the **Patient registry** workspace toolbar so the **Register patient** primary action and workspace header behave correctly across breakpoints.

**Screen:** `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart`

---

## Problem

Two regressions on the patient registry toolbar:

1. **Large screens (lg+):** The primary **Register patient** button shows **icon only**; it should show **icon + label**.
2. **Mobile (xs–sm):** The primary button **disappears entirely**; it should remain **visible as icon-only** and stay tappable inline (not buried in overflow).

Workspace header title behavior may also be wrong on small viewports — verify against the matrix below.

---

## Expected behavior

Use `AppBreakpoints` as the source of truth (`frontend/lib/core/responsive/app_breakpoints.dart`).

| Breakpoint | Width | Workspace title | Primary **Register patient** |
| ---------- | ----- | ----------------- | ---------------------------- |
| **xs, sm** (mobile) | &lt; 600 | Hidden (module icon only) | Icon only, **always inline** |
| **md** (tablet) | 600–839 | Visible | Icon only |
| **lg+** (desktop) | ≥ 840 | Visible | Icon + label |

Global toolbar actions (refresh, fault report, housekeeping, etc.) may move to the overflow menu on narrow widths; the primary action must **never** be dropped from the inline toolbar on mobile.

Reference tests (already define the contract):

- `frontend/test/shared/layout/app_workspace_toolbar_test.dart` — `mobile toolbar keeps primary action inline as icon only`, `tablet toolbar shows title but keeps primary action icon only`, `desktop toolbar shows primary action label`

---

## Likely root cause

In `patient_registry_page.dart`, the primary button is declared with `iconOnly: true`, which overrides `AppActionLabelScope` and forces icon-only mode on **all** breakpoints:

```dart
AppButton.primary(
  iconOnly: true,  // ← remove; let toolbar scope control label visibility
  leadingIcon: Icons.person_add_alt_1_outlined,
  label: l10n.patientsRegisterPatientAction,
  ...
)
```

`AppButton` already respects `AppActionLabelScope.forceIconOnly` from `AppWorkspaceToolbar` — do **not** hardcode `iconOnly: true` on workspace primary actions.

For the mobile disappearance, audit `AppWorkspaceToolbar._AdaptiveToolbarLayout` / `_measureOverflow` to ensure `pinnedInlinePrimary` is never moved into the overflow menu.

---

## Scoped work

1. **Patient registry** — Remove `iconOnly: true` from the Register patient toolbar button; keep `label`, `semanticLabel`, and `tooltip` set for accessibility.
2. **Toolbar layout** (if needed) — Ensure `pinnedInlinePrimary` stays inline on xs–md even when global actions and summary notifications are present.
3. **Tests** — Add or extend patient registry toolbar responsive tests mirroring `app_workspace_toolbar_test.dart` (mobile icon visible + tappable, tablet icon only, desktop label visible).

---

## Out of scope

- Register patient dialog / form changes
- Other workspace screens (unless the toolbar pin fix is shared infrastructure)
- i18n changes

---

## Acceptance criteria

- [ ] **lg+ (≥ 840px):** Register patient shows icon **and** label in the toolbar
- [ ] **md (600–839px):** Register patient shows icon only; workspace title visible
- [ ] **xs–sm (&lt; 600px):** Workspace title hidden; Register patient icon remains **inline and tappable** (not only in overflow)
- [ ] `flutter analyze` passes
- [ ] Toolbar responsive tests pass (`app_workspace_toolbar_test.dart` + patient registry coverage)

---

## Quality gate

From `frontend/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/layout/app_workspace_toolbar_test.dart
flutter test test/features/patients/presentation/patient_registry_page_test.dart
```
