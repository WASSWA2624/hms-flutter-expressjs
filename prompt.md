# Request Lab dialog — UI polish

Refine typography and alignment in the **Request Lab** dialog (and other clinical request flows that reuse the same shared widgets).

## Context

- Dialog: `ClinicalLabOrderActionDialog` (`frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`)
- Shared UI: `ClinicalRequestPatientContextStrip`, `ClinicalRequestSelectedCatalogTable`, `_ClinicalRequestRemoveItemButton` in `frontend/lib/shared/clinical_actions/dialogs/clinical_request_flow_dialogs.dart`
- Strings: `frontend/lib/l10n/app_en.arb` (`clinicalRequestPatientIdLabel`, etc.)

## Changes

### 1. Patient context strip

Current: entire line is semi-bold — e.g. **Name: Amina Demo-Alpha   ID: PAT-…   Encounter ID: VIS…**

Target:
- **Bold** only the field labels: **Name**, **Patient ID**, **Encounter ID**
- Values (patient name, IDs) use normal body weight
- Rename label **ID** → **Patient ID** (update `clinicalRequestPatientIdLabel` in l10n; regenerate localizations)

### 2. Actions column — Remove item

Current: both the trash icon and “Remove item” text are red (`colorScheme.error`).

Target:
- Keep the delete **icon** red (destructive cue)
- “Remove item” label uses default/neutral text color (not error red)
- Apply in `_ClinicalRequestRemoveItemButton` so all clinical request tables stay consistent

### 3. Table footer — Total row

Current: “Total” is left-aligned; amount is right-aligned in a separate column area.

Target:
- Place the total **amount in the Price column**, aligned with row prices above
- “Total” label can sit under the Test name / Type columns or span left columns — amount must line up with the **Price** column
- Increase emphasis on the total row (bolder weight than line-item prices)

## Acceptance criteria

- [ ] Patient strip shows **Name**, **Patient ID**, **Encounter ID** bold; values not bold
- [ ] “Patient ID” replaces “ID” in UI and l10n
- [ ] Remove-item icon red; label neutral
- [ ] Footer total amount aligns with Price column; total row visually bolder
- [ ] Existing tests pass; update `clinical_lab_order_action_dialog_test.dart` if labels/assertions change
- [ ] Run `flutter gen-l10n` after arb edits

## Out of scope

No changes to catalog picker, billing dialog, submit logic, or toolbar actions.
