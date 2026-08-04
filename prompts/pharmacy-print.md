# Pharmacy Print — Skip Options Dialog, Embed Filters in Preview

## Objective

From Prescription Detail, open the medication-instructions print preview in one step under the title **Print prescriptions**, with former intermediate-dialog filters available as a collapsible section beside Facility details. Preserve Print History and existing print HTML/permission behavior.

## Context

**Current behavior**

1. Prescription Detail Actions exposes **Print instructions** (`pharmacyPrintInstructionsAction`).
2. That action opens `showPharmacyPrintInstructionsOptionsDialog` (medication checkboxes; hide zero-quantity / hide partial / include history switches; optional history checkboxes).
3. Confirm then calls `PrintDocumentTemplates.medicationInstructions`, which opens `showAppPrintPreviewDialog` titled **Medication instructions** (`pharmacyReportTitle`), with Facility details section pickers and live branding preview.
4. Dispense History retains a separate **Print History** path via `_printDispenseHistory`.

**Intended behavior**

1. Rename the detail action to **Print**.
2. Skip the intermediate options dialog; open the print-preview dialog directly.
3. Title that preview dialog **Print prescriptions**.
4. Below Facility details in the Sections pane, add a collapsible section holding the former options (medication inclusion, filter flags, optional history selection) using **multi-select checkboxes** (not radios / exclusive selection).
5. Changing those options must rebuild the preview body HTML live (same filtering rules as `pharmacyInstructionsHtml` today).

**Reference UI (current):** Prescription Detail → Print instructions → options dialog → Medication instructions preview with Facility details.

## Requirements

1. Rename Prescription Detail print action label from “Print instructions” to **Print** (l10n). Keep the same permission gate (`canPrintPharmacyInstructions` / `pharmacyPrintInstructionsRequirement`); unauthorized users must not see the control.
2. On Print, open the medication-instructions print preview **without** `showPharmacyPrintInstructionsOptionsDialog`. Do not require a second confirm before preview.
3. Set the preview **dialog** title to **Print prescriptions**. Keep the printed document body title as **Medication instructions** (`pharmacyReportTitle`) unless a dedicated document-title key is already required by the template API—do not rename unrelated physiotherapy “Print instructions” strings.
4. In the preview Sections pane, keep the existing **Facility details** collapsible picker unchanged in behavior (brand, address, phone, email, type, ID).
5. Add a second collapsible section (e.g. **Print options** / medications-to-include) **below** Facility details that includes:
   - Multi-select **checkboxes** for medications (default: all selected; disable Print when none selected).
   - **Checkboxes** (not radios) for: hide zero-quantity items (default on), hide partially dispensed items (default off), include dispense history (default off).
   - When include history is on: select-all plus per-record multi-select checkboxes for timeline entries (same data as today’s options dialog).
6. Wire option changes into live preview rebuild: apply the same filters as `pharmacyInstructionsHtml` / history inclusion so the right-hand preview updates without closing the dialog. Facility branding rebuilds must continue to work together with body filters.
7. Preserve **Print History** on the Dispense History panel (`_printDispenseHistory`) and its current preview/print path.
8. Reuse existing helpers (`pharmacyInstructionsHtml`, `pharmacyDispenseHistoryHtml`, `PrintDocumentTemplates.medicationInstructions`, `AppPrintPreview` / `AppFormSection` / design-system controls). Prefer extending the preview sections column over a one-off parallel dialog. Remove or stop calling the intermediate options dialog if unused; avoid orphaned UX.
9. Update l10n (`app_en.arb` + generated locals), pharmacy workspace wiring, and tests that assert “Print instructions” on Prescription Detail / print flow.
10. States: loading/empty/error of the existing print preview path unchanged; empty medication selection disables Print; empty history list when include-history is on shows an empty selection (no crash); theme tokens for light/dark; responsive Sections + Preview panes without clipping.

## Constraints

- Follow `prompts/.cursor/prompt.mdc` implementation rules (reuse contracts, RBAC/ABAC, no unauthorized chrome, theme tokens, no unrelated refactors).
- Do not change dispense, cancel, pricing, or Print History semantics.
- Do not broaden print permissions.
- Prefer pharmacy-scoped extension of the preview sections UI over rewriting shared print chrome for all document kinds; if shared APIs gain optional “extra sections” / body rebuild callbacks, keep defaults backward-compatible for other templates.

## Acceptance Criteria

| ID | Criterion | Traces to |
| --- | --- | --- |
| A1 | Prescription Detail shows **Print** (not “Print instructions”) when print is allowed; control absent when not allowed. | R1 |
| A2 | Tapping Print opens the print-preview dialog immediately; the intermediate options dialog does not appear. | R2, R8 |
| A3 | Preview dialog chrome title is **Print prescriptions**. | R3 |
| A4 | Sections pane shows Facility details and a second collapsible print-options section with multi-select checkboxes (no radio/exclusive medication selection). | R4, R5 |
| A5 | Toggling medications/filters/history updates the live preview using existing filter semantics; Print disabled with zero medications selected. | R5, R6, R10 |
| A6 | Print History from Dispense History still works as today. | R7 |
| A7 | Existing pharmacy print HTML columns, totals, patient/order context, signatures, and facility branding behavior remain. | R6, R8 |
| A8 | Unit/widget tests updated for label, direct preview open, and option-driven preview filtering; unauthorized print control remains absent. | R9, R10 |

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` — `_openPrintInstructionsDialog`, Actions **Print**, Print History
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_print_instructions_options_dialog.dart` — current options UI/state to relocate or retire
- `frontend/lib/features/pharmacy/presentation/pharmacy_instructions_print_helpers.dart` — body HTML + filters
- `frontend/lib/shared/printing/app_print_preview.dart` — Sections pane / Facility details / live HTML rebuild
- `frontend/lib/shared/printing/templates/print_document_templates.dart` — `medicationInstructions`
- `frontend/lib/features/pharmacy/presentation/pharmacy_access.dart` — print requirement
- `frontend/lib/l10n/app_en.arb` — print labels/titles
- `frontend/test/features/pharmacy/presentation/pharmacy_workspace_page_test.dart` and related pharmacy permission/print tests

## Verification

- Update/add widget tests: Print label; no options dialog; preview titled Print prescriptions; sections include print options; filter changes affect preview HTML; Print History unchanged; print control hidden without permission.
- Run focused pharmacy presentation tests and `flutter analyze` on touched files.
- Manual: Prescription Detail → Print → Split view; toggle Facility details and print options; confirm preview; print; confirm Print History still opens separately.
