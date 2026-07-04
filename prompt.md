# Refine the “Choose lab tests” catalog picker dialog

## Context

The **Choose lab tests** modal (`ClinicalLabRequestCatalogDialog`) is opened from the clinical lab order flow when the user taps **Add items**. It lets clinicians browse and multi-select individual lab tests or lab panels from a searchable table before returning to the parent order dialog.

**Primary files**

- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_request_catalog_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart` (caller)
- `frontend/lib/l10n/app_en.arb` (+ generated l10n)
- `frontend/test/shared/clinical_actions/clinical_lab_order_action_dialog_test.dart`

## Required changes

### 1. Dialog title

Rename the title from **“Choose lab tests”** to **“Choose lab tests or panels”**.

- Update l10n key `clinicalLabRequestCatalogPickerTitle` in `app_en.arb` and regenerate localizations.

### 2. Test type switcher: tabs → radio buttons

Replace the current `SegmentedButton` (**Individual tests** / **Lab panels**) with a horizontal **radio group** using the existing `AppRadioGroup` component (same pattern as elsewhere in the app).

- Labels: **Individual tests**, **Lab panels**
- Preserve current behavior: switching mode reloads the appropriate catalog and keeps checkbox multi-select within the active mode.
- Icons are optional; prioritize clarity and consistency with `AppRadioGroup` usage elsewhere.

### 3. Unit price column spacing

The **Unit price** column values sit too close to the right edge and appear clipped (see screenshot).

- Add sufficient right padding (or equivalent column/cell alignment) so currency values (e.g. `UGX 20,000`) are fully visible and visually balanced.
- Apply only to the price column; do not alter other columns unnecessarily.
- Verify at maximized dialog width and with long formatted prices.

### 4. Primary action: confirm instead of “Done”

Replace the footer **Done** button with a clearer confirm action:

- Label: **Confirm selected tests or panels** (or a concise variant that names both item types).
- Add an appropriate leading icon (e.g. `Icons.check_circle_outline` or `Icons.playlist_add_check`).
- **Confirm** applies staged selections to the parent lab order and closes the dialog.
- Add a **Cancel** tertiary button (reuse `commonCancelActionLabel`) that discards changes and closes—same behavior as the close (X) control.

### 5. Close (X) must cancel, not commit

**Current problem:** selections are applied immediately via `onSelectionChanged` on the parent `_requests` list, so closing the dialog (X or backdrop) keeps whatever was checked—even if the user intended to abandon the session.

**Required behavior:**

- Stage selections **inside** the catalog dialog while it is open.
- Only commit to the parent when the user taps **Confirm selected tests or panels**.
- **Cancel**, **Close (X)**, and equivalent dismiss paths must **discard** staged changes and leave the parent order unchanged.
- On open, initialize the staging state from the parent’s current selection.

## Implementation notes

- Refactor `showClinicalLabRequestCatalogDialog` / `ClinicalLabRequestCatalogDialog` so selection mutations are local until confirm; return the final selection (or `null` on cancel) via `Navigator.pop`.
- Update `ClinicalLabOrderActionDialog._openCatalogPicker` to apply the returned selection only on confirm.
- Keep checkbox multi-select, search, filters, column settings, and selected-count display working with staged state.
- Add new l10n keys for the confirm action label; do not hardcode strings.
- Update widget tests: title text, radio group instead of segmented control, confirm/cancel actions, and that dismiss/cancel does not mutate parent selections.

## Acceptance criteria

- [ ] Dialog title reads **Choose lab tests or panels**.
- [ ] **Individual tests** / **Lab panels** are radio buttons, not segmented tabs.
- [ ] Unit prices are fully visible with comfortable right padding.
- [ ] Footer shows **Cancel** and **Confirm selected tests or panels** (with icon).
- [ ] Confirm applies selections; Cancel and Close (X) revert without changing the parent order.
- [ ] Existing catalog search, filter, and multi-select behavior still works.
- [ ] Tests pass and cover confirm vs cancel/dismiss behavior.
