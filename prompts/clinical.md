# Finish Add Diagnosis Density Polish

Final polish on `ClinicalDiagnosisActionDialog`: match transfer-action height to search fields, drop the Diagnosis type label text, and minimize transfer-table row height. Inventory: `screens/clinical.md`. Follow `prompts/.cursor/prompt.mdc`.

## Context

Opened from `/clinical` encounter **Add diagnosis**. Transfer UX is largely complete. Remaining polish: **Add selected diagnosis** and **Remove selected diagnosis** still do not match search-field height; the **Diagnosis type** label text adds vertical chrome above Primary / Secondary / Differential; transfer-table rows still have excess vertical padding relative to title + subtitle content.

**Matched toolbar height:** search input and adjacent transfer action share the same rendered height in each pane toolbar.

## Requirements

1. Make **Add selected diagnosis** and **Remove selected diagnosis** the same height as their adjacent dense search fields on both panes.
2. Remove the visible **Diagnosis type** label text; keep Primary / Secondary / Differential borderless radios selectable, with an accessible semantic label only (no on-screen title).
3. Minimize transfer-table row and header vertical padding/density on both panes so row height is content-tight around the diagnosis title and subtitle while remaining tappable and readable.
4. Preserve Cancel / **Add diagnosis**, default Primary, dual-pane search, row-click toggle, Add/Remove transfer rules, catalog search/load/retry, caller write gate, loading/empty/error/success, theme tokens, and responsive stacking.

## Constraints

- Reuse `ClinicalDiagnosisActionDialog`, `AppListTable`, `AppButton`, `AppTextField`, and `AppRadioGroup`; extend shared dense metrics only if required for equal toolbar height or tighter rows.
- No diagnosis-type semantics, catalog source, or submit-contract changes; no unrelated clinical refactors.
- Unauthorized UI remains absent via the existing caller write gate.

## Acceptance Criteria

- Both pane transfer actions match search-field height (1).
- No on-screen **Diagnosis type** label; radios remain usable with semantics (2).
- Transfer rows/headers are visually shorter and content-tight on both panes (3).
- Submit, transfer, empty, error, retry, and success behavior still work (4).
- Update dialog tests for absent Diagnosis type label and preserved radio/actions; manually verify light/dark on mobile, tablet, and desktop.

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_button.dart`
- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/shared/components/app_radio_group.dart`
- `screens/clinical.md`
- `frontend/test/shared/clinical_actions/clinical_diagnosis_action_dialog_test.dart`
