# Refine Prescribe Dialog Selected Medicines Table

Rebuild `ClinicalPrescriptionActionDialog` so selected medicines use `AppListTable` with search-bar actions, matching lab/radiology selected-items UX. Follow `prompts/.cursor/prompt.mdc`.

## Context

Prescribe opens from clinical encounter **Prescribe**. Today: help copy (`clinicalRequestMainPanelHelp`), **Bill on dispense** / **Pay at prescribe** toggle, top toolbar (**Add medicine**, **Review billing**), and **Build prescription** `ClinicalRequestSelectionManager`.

**Selected medicines table:** `AppListTable` of lines added via **Add medicine**. Checkboxes select rows for bulk remove; clinician can still add medicines afterward.

## Requirements

1. Remove the help text ("Review selection, add catalog items, then confirm billing").
2. Remove **Bill on dispense** / **Pay at prescribe** and the pay-now summary bar. Default submit to bill-later unless **Review billing** was confirmed; no mode toggle required to prescribe.
3. Remove the top toolbar and **Build prescription** manager. Body = selected-medicines `AppListTable` (+ failure banner). Keep footer **Cancel** / **Prescribe**.
4. Use `AppListTable` + `AppListTableSearch` with **Filters**, **Settings** (column visibility), and trailing actions: **Add medicine**, **Review billing**, **Remove selected**. Match clinical catalog/worklist search-bar patterns.
5. First column = row checkbox. **Remove selected** deletes checked lines only (reuse shared confirm if one already exists). Empty selection disables the action.
6. Default-visible columns: medicine name, dose, route/frequency (or readable summary), quantity. Nest duration, instructions, price via Settings. Keep row edit (existing line dialog) and single-row remove if the table pattern supports it.
7. **Add medicine** opens the existing line dialog; Done appends a row. **Review billing** opens existing billing flow when ≥1 medicine exists; disable when empty or saving.
8. Cover saving, empty ("No medicines added yet"), no-search-results, line validation, submit failure, success close. Unauthorized prescribe UI must not render. Responsive; theme tokens only.
9. Tests: help + payment toggle absent; table/search actions present; checkbox remove-selected; add adds a row; review billing gated on non-empty list.

## Constraints

- Reuse `AppListTable`/`AppListTableSearch`, add-medicine and billing dialogs, submit payload, and clinical write gate. Prefer shared clinical request table helpers over a prescribe-only table.
- Do not change pharmacy/backend contracts beyond client bill-later defaulting above.
- No raw UUIDs; use drug display names and readable dosing.

## Acceptance Criteria

- Help copy and payment-mode controls gone (Req 1–2).
- No top toolbar or Build prescription dropdown; lines live in `AppListTable` (Req 3–4).
- Search bar has Filters, Settings, Add medicine, Review billing, Remove selected (Req 4–5, 7).
- Checkbox + Remove selected deletes only selected lines; Add medicine still works (Req 5–6).
- Core dosing columns default-visible; Settings nests extras (Req 6).
- Submit works with bill-later default and optional reviewed billing (Req 2, 7–8).
- Req 9 tests pass; unauthorized controls absent.

## Relevant Files

- `frontend/lib/shared/clinical_actions/dialogs/clinical_prescription_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/clinical_actions/`
- `screens/clinical.md` (update only if Prescribe actions/labels change)
