# Simplify Add Diagnosis Dialog Layout

Simplify `ClinicalDiagnosisActionDialog` so diagnosis type and transfer panes are compact and less nested. Inventory: `screens/clinical.md`. Follow `prompts/.cursor/prompt.mdc`.

## Context

Opened from `/clinical` encounter **Add diagnosis**. Current UI uses bordered `AppRadioGroup` cards for Primary / Secondary / Differential, and available/selected panes wrapped in bordered boxes with titles, match counts, and a search/**Add** row above a nested `AppListTable` (shows `#` plus a wide select column). Inner table scroll leaves pane chrome fixed.

**Borderless radio:** control + label only (no per-option card border or fill); control vertically centered with the label; equal option height; horizontal when space allows.

## Requirements

1. Render diagnosis type as borderless radios (Primary / Secondary / Differential); keep horizontal layout when space allows; align radio with label; remove per-option borders and filled cards.
2. Remove the **Available diagnoses** title and the matches count (`Showing N of M matches`) from the available pane.
3. Keep search and **Add** inside the available pane’s table-section chrome so the table’s own surface dominates the pane (not a separate toolbar stacked above an inset nested table body).
4. Hide the `#` row-number column in both transfer tables; checkbox/select is the leftmost column.
5. Size the select column to checkbox width only; header and row checkboxes share one vertical alignment line.
6. In each transfer pane, scroll search/actions and rows together within the pane; do not freeze pane header chrome while only the table body scrolls.
7. Reduce outer pane margin/border chrome on both panes so `AppListTable` is the primary surface; apply the same scroll and chrome treatment to **Selected diagnoses** while keeping Deselect and selection behavior.
8. Preserve Cancel / **Add diagnosis**, default type Primary, catalog search/load/retry, Add/Deselect transfer rules, caller write gate, loading/empty/error/success feedback, theme tokens, and responsive stacking.

## Constraints

- Reuse `ClinicalDiagnosisActionDialog`, `AppListTable`, and `AppRadioGroup`; extend shared presentation only if required for borderless radios, hiding `#`, or tight select width.
- No diagnosis-type semantics, catalog source, or submit-contract changes; no unrelated clinical refactors.
- Unauthorized UI remains absent via the existing caller write gate.

## Acceptance Criteria

- Type radios have no card borders; horizontal and label-aligned when space allows (1).
- Available pane has no title or match count; search/**Add** sit in pane/table chrome (2–3).
- No `#` column; select column is checkbox-tight and vertically aligned (4–5).
- Each pane scrolls as one unit; reduced outer border/margin on both panes (6–7).
- Submit, validation, empty, error, retry, and success behavior still work (8).
- Cover with dialog/widget tests for radio presentation and column layout; manually verify light/dark on mobile, tablet, and desktop.

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`
- `frontend/lib/shared/components/app_radio_group.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `screens/clinical.md`
- Clinical diagnosis dialog tests under `frontend/test/`
