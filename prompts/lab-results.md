# Clinical Lab orders display & cancel

Align the clinical encounter **Lab orders** section with how the lab module shows results—panel sections and flat test rows (Tests / Range name / Result / Flag)—and give clinicians clear cancel actions for pending orders only. Remove nested order→item table chrome; do not invent a parallel results UI.

## Context

- Clinical panel: `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart` (`ClinicalLabOrdersTablePanel`, nested `_ClinicalLabOrderGroup` / item `DataTable`).
- Clinical wiring / mutations: `clinical_workspace_page.dart`, `clinical_workspace_controller.dart` (`cancelLabOrder`, `updateLabOrder`, `deleteLabOrder`, create/edit via lab order dialog).
- DTO / entities: `clinical_dtos.dart`, `clinical_entities.dart` (`ClinicalRelatedRecord`, `ClinicalLabOrderItem`); lab orders still prefer `human_friendly_id` for ids in places.
- Order request/edit dialog: `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart` (+ catalog dialog).
- Lab result entry (target UX): `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` — patient header, panel `AppCollapsibleSection`s (e.g. Abdominal Pain Panel), table columns **Tests | Range name | Result | Flag**, Pending (not `—`), High/INVALID styling, **Preview report**.
- Lab status / flags: `lab_status_display.dart`, `app_clinical_results_preview.dart`, `lab_reference_range_format.dart`.
- Backend: `backend/src/modules/lab-order/` (`POST/PUT/DELETE /api/v1/lab-orders`); workspace results `backend/src/modules/lab-workspace/` (`save-result`, `delete-items`, reject/reopen). Order ids accept UUID or friendly id.
- Current gaps: nested expandable order tables; Value / Status / Arrival / unpaid badges and `—` placeholders; batch cancel/delete strings reuse **radiology** keys; no item-level cancel UI; clinical layout diverges from lab panel+rows; completed orders may still be cancellable if gates are weak.
- Flat-row pattern to mirror: `ClinicalDiagnosesTablePanel` in the same detail-panels file.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, and existing clinical action / `AppCollapsibleSection` patterns.

## Requirements

1. **Lab-module display parity:** Render clinical Lab orders like lab result entry: group by panel (or single-test title) using `AppCollapsibleSection`; inside each panel show a flat table/list of tests with columns **Tests | Range name | Result | Flag** (read-only on clinical). Prefer reusing or adapting lab presentation helpers (`_LabPanelResultBlock` / range labels / flag display) rather than a third chrome.
2. **No lazy nesting:** Do **not** use expandable parent order rows that reveal indented child `DataTable`s. No nested `_ClinicalDetailDataTableContainer` padding for this section. Each panel section is independent; test rows are full-width within the panel.
3. **Drop leftover order columns:** Do **not** show Value, Arrival time, or payment/unpaid chips on this clinical Lab orders list. Do not show empty `—` for pending results—use localized Pending (same idea as lab entry). Ordered/workflow noise belongs elsewhere; keep the section scannable for results + cancel.
4. **Cancel (doctors / clinical write):** Primary mutation is **Cancel** for pending lab work only. Clinicians with `clinicalLabOrderWriteRequirement` (existing clinical∪lab write gate) can cancel; do not open lab result entry from this panel unless product already does so elsewhere.
5. **Pending-only cancel:** Allow cancel only while the order/test is still pending in lab (e.g. `ORDERED` / `PENDING`—tighten `_canCancelLabOrder` and prefer a backend guard so `COMPLETED` / verified cannot be cancelled). After cancel, the work disappears from lab pending queues (existing cancel → cancelled status). Completed or already-resulted tests cannot be cancelled.
6. **Panel vs individual test:**
   - Cancelling a **panel** means cancelling the whole order / all pending tests in that panel—not a separate “panel-only” entity.
   - Cancelling a **single test** is allowed only for that pending item (wire item cancel via existing lab `delete-items` / reject path if available; otherwise document and implement the smallest safe API use). Do not cancel completed siblings when cancelling one pending test.
7. **Selected cancel:** Support cancel for the selected pending order(s) and/or selected pending test(s) with clear confirm copy (localized Cancel, not Delete/hard wipe). Fix batch header actions so they use **lab** l10n keys—not radiology cancel/delete strings.
8. **Edit:** Keep Edit order only where the API still allows (typically pre-process `ORDERED`); do not leave Edit as a no-op. If product prefers cancel-only on clinical, hide Edit once cancel paths cover the need—do not leave both confusing.
9. **Data enrichment:** If clinical order payloads lack range/result/flag fields that lab entry has, enrich DTO mapping or load the minimum fields needed for display (catalog range label + stored result/flag when present). Friendly ids may remain for display; mutations must use ids the API accepts (UUID or friendly per existing lab-order schema).
10. **l10n + tests:** English strings for panel/test cancel, confirms, pending labels, column headers if new; widget tests that the section is non-nested, columns match lab entry (no Value/Arrival/unpaid), cancel disabled for completed, radiology strings not used on lab batch actions.

Optional enhancements: none (do not add Preview report on clinical Lab orders unless already required—Preview stays on lab entry).

## Constraints

- Reuse `AppCollapsibleSection`, lab result display helpers, clinical dialog confirm patterns, and `clinicalLabOrderWriteRequirement`. Do not build a second lab workbench inside clinical.
- Prefer adapting lab panel+row presentation for **read-only** clinical use; do not migrate clinical into full result entry.
- No unrelated clinical refactors (diagnoses, vitals, notes, radiology/pharmacy orders) beyond Lab orders display/cancel.
- Prefer frontend cancel gating + DTO enrichment; add/confirm backend completed-cancel rejection if product requires hard enforcement.
- Preserve create-lab-order flow via existing clinical lab order dialog.

## Acceptance Criteria

- AC1 (Req 1–3): Clinical Lab orders show panel collapsible sections and flat Tests | Range name | Result | Flag rows; no nested child tables; no Value/Arrival/unpaid/`—` leftovers.
- AC2 (Req 4–6): Cancel works for pending orders/tests only; panel cancel cancels the whole pending panel/order; completed cannot cancel; cancelled work leaves lab pending queues.
- AC3 (Req 7–8): Selected cancel uses lab-specific copy; Edit is honest (working or removed).
- AC4 (Req 9–10): Display has range/result/flag when available; English l10n and tests cover layout, pending-only cancel, and no radiology batch strings.

## Relevant Files

- `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart`
- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
- `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart`
- `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_lab_order_action_dialog.dart`
- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
- `frontend/lib/features/lab/presentation/lab_status_display.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/shared/components/app_clinical_results_preview.dart`
- `frontend/lib/shared/lab_catalog/lab_reference_range_format.dart`
- `backend/src/modules/lab-order/`
- `backend/src/modules/lab-workspace/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
