# Tighten Add Diagnosis Transfer Pane Density

Make `ClinicalDiagnosisActionDialog` transfer panes denser: compact search, tighter select column, fuller diagnosis text, and less row padding. Keep borderless diagnosis-type radios. Inventory: `screens/clinical.md`. Follow `prompts/.cursor/prompt.mdc`.

## Context

Opened from `/clinical` encounter **Add diagnosis**. Diagnosis-type radios are acceptable. Remaining issues: available-pane search field is too tall; transfer action still reads **Add**; select/checkbox column remains wider than the control; name/subtitle truncate despite spare width; table rows use excess vertical padding vs content. Apply the same density treatment to available and selected panes.

**Select column:** leftmost checkbox column sized to the checkbox only (no spare horizontal slack).

## Requirements

1. Keep diagnosis-type radios borderless (Primary / Secondary / Differential); no visual redesign of that control.
2. Compact the available-pane search field so its height aligns with the adjacent transfer action (dense/compact field chrome, not a tall labeled stack that dwarfs the button).
3. Relabel the available transfer action to **Add selections** (keep current `+` / add icon; do not require a right-arrow icon).
4. Shrink the select/checkbox column on both panes to checkbox-only width; header and row checkboxes stay vertically aligned on one line.
5. Give the Name column the remaining pane width so diagnosis title and detail subtitle (code | category | …) are fully readable without unnecessary ellipsis when space allows; wrap or multi-line only if needed to avoid clipping.
6. Reduce table row and header vertical padding/density on both panes so rows are content-tight while remaining tappable and readable.
7. Apply the same select-column, name-visibility, and row-density treatment to the selected pane (count + **Deselect** unchanged in behavior).
8. Preserve Cancel / **Add diagnosis**, default type Primary, catalog search/load/retry, Add selections / Deselect transfer rules, caller write gate, loading/empty/error/success, theme tokens, and responsive stacking.

## Constraints

- Reuse `ClinicalDiagnosisActionDialog`, `AppListTable`, and existing theme tokens; extend shared table/field density only if required for checkbox-tight columns or compact rows in this dialog.
- No diagnosis-type semantics, catalog source, or submit-contract changes; no unrelated clinical refactors.
- Unauthorized UI remains absent via the existing caller write gate.

## Acceptance Criteria

- Diagnosis-type radios unchanged in presentation from current borderless style (1).
- Search height matches the transfer action row; no oversized search stack (2).
- Available action label is **Add selections** with add icon (3).
- Select column is checkbox-tight on both panes; Name uses remaining width with readable details (4–5, 7).
- Row/header vertical density is content-tight on both panes (6–7).
- Transfer, submit, empty, error, retry, and success behavior still work (8).
- Update dialog tests for the new action label and column density; manually verify light/dark on mobile, tablet, and desktop.

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/l10n/app_en.arb`
- `screens/clinical.md`
- `frontend/test/shared/clinical_actions/clinical_diagnosis_action_dialog_test.dart`
