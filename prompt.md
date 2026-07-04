# Lab Result Entry — Modal & UI Polish

Refine the **Lab Result Entry** dialog (`lab_result_entry_dialog.dart`) and shared modal infrastructure so the UI matches app-wide conventions. Reference: Lab Result Entry modal (order header actions, results table with checkboxes, footer action bar).

## Scope

### 1. Modal title capitalization (shared, all dialogs)

**Problem:** Modal titles are inconsistent; some are not properly capitalized.

**Fix at the shared component level** — do not patch individual dialogs.

- Update `AppDialog` (`frontend/lib/shared/components/app_dialog.dart`) so every modal title is rendered in **Title Case** (capitalize each significant word; preserve acronyms/IDs).
- Apply normalization in the dialog header (`_DialogHeader`) when rendering the `title` widget — e.g. extract plain text from `Text`/`RichText` children and re-apply styled Title Case, or introduce an optional `AppDialogTitle` helper if needed.
- Ensure existing titles like `"Lab Result Entry"` remain correct; fix any ALL CAPS or sentence-case titles app-wide without changing l10n strings unless necessary.
- Add/update tests in `app_dialog_test.dart`.

### 2. Icon + label on large screens (order & panel actions)

**Problem:** Edit and Delete controls in the order header and panel header are icon-only (`iconOnly: true`) even on wide layouts.

**Convention:** On large screens, action buttons show **icon + label**; icon-only is for compact/toolbar contexts only.

Affected controls in `lab_result_entry_dialog.dart`:
- Order header: Edit order, Delete order (`_LabOrderSection`, ~lines 1381–1398)
- Panel header: Delete panel (`_PanelGroupHeader`, ~lines 2332–2341)

**Fix:**
- Remove hardcoded `iconOnly: true` where labels exist.
- Wrap the dialog content (or action regions) in `AppActionLabelScope` using the same breakpoint logic as `app_workspace_toolbar.dart` (`AppBreakpoints.of(context).showsToolbarActionLabels`), so labels appear on large screens and icons-only on small screens.
- Keep `semanticLabel` and `tooltip` for accessibility.

### 3. Destructive (red) delete styling

**Problem:** Delete actions look like generic tertiary buttons; delete should read as destructive.

**Fix:**
- Style all **delete** actions with the theme danger color: `Theme.of(context).statusColors.danger` (or `colorScheme.error` if that is the established pattern).
- Apply via `AppButton`’s existing `color` parameter — extend `AppButton` only if needed for hover/pressed/disabled states on custom colors.
- Affected buttons:
  - Order header delete
  - Panel header delete
  - Footer **Delete order** action

Do **not** recolor non-destructive actions (Edit, Restore test, Preview report, etc.).

### 4. Results table — checkbox column alignment

**Problem:** In the results table, the selection checkbox in the first column is vertically misaligned relative to the test name and other row cells.

**Fix in `_LabResultTestCell` and/or `_LabResultTableCell`:**
- Align checkbox with the first line of row content (center or top-align consistently with other columns).
- Match padding used by `_LabResultTableCell` (`theme.spacing.sm`) so the checkbox column lines up with Reference range, Result, Flag, and Action cells.
- Verify alignment for both standalone tests and tests inside panels (`embeddedInPanel: true`).

### 5. Footer action bar cleanup

**Problem:** The footer duplicates the modal’s top-right close control.

**Fix in `LabResultEntryDialog.build` footer `actions`:**
- **Keep:** Preview report, Create lab order, Edit order, Delete order.
- **Remove:** Close button (`commonCloseActionLabel`) — users already close via the header ✕.
- Style **Delete order** as destructive (see §3).
- Leave Preview report, Create lab order, and Edit order unchanged.

Also remove the Close button from the empty/loading footer state if present.

## Constraints

- Minimal diff — reuse `AppDialog`, `AppButton`, `AppActionLabelScope`, and theme tokens; no new abstractions unless required.
- Respect light/dark themes for danger styling.
- Do not change lab business logic, result entry workflow, or API behavior.
- Run existing tests; add targeted widget tests where behavior changes.

## Verification

1. Open Lab Result Entry on a wide viewport (≥ toolbar label breakpoint): order/panel Edit and Delete show icon + label; Delete is red.
2. Narrow viewport: those actions collapse to icon-only with tooltips.
3. Results table checkboxes align with row content across panels and standalone rows.
4. Footer shows four primary actions (no Close); Delete order is red.
5. All app modals render titles in consistent Title Case.
