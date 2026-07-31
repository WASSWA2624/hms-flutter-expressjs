# Radiology procedure workbench (table + status actions)

Refine the Radiology workflow detail **Procedures** section so it is a flat, table-like workbench—not nested cards. Drive the row by clear status → action transitions (Procedure done → awaiting report → Mark report done), allow undoing accidental status changes, open the existing comprehensive report dialog from the waiting-for-report state, and keep results/status fresh via realtime refresh.

## Context

- Detail dialog / workbench: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (`_RadiologyDetailBody`, `_ProcedureWorkbenchSection`, `_procedureWorkbenchRows`, `_showStudyDialog` / `createStudy`, `_showReportDialog`).
- Report dialog (keep): rich technique/findings/impression/recommendation + multi-source images + print footer already shipped in the same file (`_ReportEditDialog`).
- Print / compose helpers: `radiology_workspace_page.print.dart`, `radiology_workspace_page.detail_cells.dart`.
- Controller: `radiology_workspace_controller.dart` — already has `listenForRealtimeRefresh` / adaptive polling; study + draft/finalize/assign mutations.
- Entities: `radiology_entities.dart` / DTOs — `RadiologyWorkflow`, `RadiologyOrder`, `RadiologyRequestedTest`, `ImagingStudy`, `RadiologyResult`, `RadiologyNextActions` (`canCreateStudy`, `canCreateDraftResult`, `canFinalizeResult`, `canAssign`, …).
- Access: `radiology_access.dart` (write / print gates).
- Current pain (see live detail, e.g. `RAD0000006` Ankle and Foot X-Ray): Procedures still render as a **bordered nested card** with a `Wrap` of chips (id · name · modality · body · Pending). Actions are easy to miss or absent under weak `canCreateStudy` gating; layout is not a scannable table; no numbered column; no undo after accidental Done; row click does not open reporting; status labels do not clearly say “waiting for report.”
- Target density: lab result entry / clinical flat rows (`lab_result_entry_dialog.dart`, clinical diagnoses/lab panels)—full-width rows, columns aligned, actions on the right.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppCollapsibleSection` / `AppListTable` / `AppDialog` patterns.

## Requirements

1. **Remove nested procedure chrome:** Inside the Procedures `AppCollapsibleSection`, do **not** wrap each procedure in a bordered card / nested panel. No inner `DecoratedBox` “tile” around the row. Rows are flat and full-width within the section (same idea as clinical diagnoses / lab panel rows).

2. **Table-like procedure list:** Render procedures as a dense table (prefer `AppListTable` or an equivalent aligned column layout). Columns, left → right:
   - **#** — 1-based row number
   - **Procedure ID** — friendly order/procedure id (e.g. `RAD0000006`)
   - **Procedure name** — study / catalog name (e.g. Ankle and Foot X-Ray)
   - **Modality** — humanized when known (X-ray, CT, MRI, …)
   - **Body organ / region** — body region (and laterality when useful, without crowding)
   - **Status** — localized, humanized (not raw enums; not “Not available”)
   - **Actions** — extreme right; primary status-changing control(s) only (overflow ok on narrow layouts)

   Prefer `order.requestedTests` when present; otherwise one row for the order—do not invent fake multi-rows.

3. **Status → action contract:**
   - **Pending** (just requested / not yet performed): primary action **Procedure done** (permission-gated). Calling it must run the real performed path (`createStudy` / existing Done study dialog)—not a cosmetic checkbox.
   - After Procedure done: status becomes **Done — waiting for report** (or equivalent clear localized wording). Primary action becomes **Mark report done** (opens / completes reporting—reuse the existing comprehensive report dialog; do not rebuild a second reporter).
   - While waiting for report (and when a draft already exists): **clicking the procedure row** opens the same comprehensive report dialog. Keep an explicit Mark report done / Write report control as well so the affordance is obvious.
   - After the report is released/final: status **Reported** (or existing released wording); hide Mark report done; row may still open a read-only / addendum path only if product already supports it—do not invent a new viewer.

4. **Undo / reverse status:** Accidental Procedure done or premature report-state change must be reversible with a clear **Undo** / **Revert** action (confirm dialog, localized). Prefer existing backend/controller paths (delete unreleased study, reopen draft, cancel unreleased result, etc.). If no API exists, add the **smallest** safe radiology-workspace undo for unreleased work only—do not allow undo of finalized/released reports without the existing addendum/amend flow. Undo must refresh the row status and next actions immediately.

5. **Keep the shipped report dialog:** Do not regress rich text, multi-source images (local / remote / PACS / study assets), draft/release, or print-in-footer. Mark report done must land in that dialog.

6. **Assign typist (keep):** When status is waiting for report, keep Assign typist as a secondary row/header action using existing assign APIs—do not invent a parallel staff module.

7. **Realtime results / status:** Radiology workflow detail (selected order + procedure statuses + draft/released results) must update in **real time** when another client or mutation changes the workflow. Reuse `radiology_workspace_controller` realtime refresh / adaptive polling; ensure an open detail dialog rebuilds from the refreshed selected workflow—no stale Pending after Done elsewhere. Do not add a second polling stack.

8. **Honest empty / gated actions:** If Procedure done cannot run (`canCreateStudy` false, billing gate, etc.), do not show a dead enabled button—omit or disable with existing denial/billing copy. Do not leave Pending rows with no explanation and no next step.

9. **l10n + tests:** English strings for column headers (#, Procedure ID, name, modality, body organ, status, actions), **Procedure done**, **Done — waiting for report**, **Mark report done**, Undo/Revert confirms, and any new status labels. Widget tests for: flat non-nested table columns; Pending → Procedure done; waiting-for-report → Mark report done + row opens report dialog; Undo restores prior status when allowed; detail reflects realtime/controller refresh after mutation; no bordered nested procedure cards.

Optional enhancements: none (do not expand desk tabs or redesign patient header in this prompt).

## Constraints

- Reuse `AppPatientDetails`, Procedures `AppCollapsibleSection`, existing `createStudy` / draft/finalize/assign/print paths, and controller realtime refresh. Do not invent a second radiology desk.
- Prefer frontend layout + status labeling + wiring of existing next-actions; only add backend undo glue if unreleased study/result cannot be reversed today.
- No return of Request details / Timeline / Imaging floor–Reporting radios / empty “No imaging studies” wall.
- Preserve write / print / assign permission gating.
- Responsive: table columns may collapse into overflow actions on mobile; # / id / name / status / actions must remain reachable.

## Acceptance Criteria

- AC1 (Req 1–2): Procedures section is a flat table (# | ID | name | modality | body | status | actions) with no nested bordered procedure cards.
- AC2 (Req 3, 5–6, 8): Pending shows Procedure done; after done, status is waiting-for-report with Mark report done; row click opens the existing comprehensive report dialog; typist assign remains available while waiting; gated actions are honest.
- AC3 (Req 4): Undo/Revert can reverse accidental unreleased Procedure done (and unreleased report-state changes where supported) with confirm + refreshed row.
- AC4 (Req 7): Open detail / procedure status and results refresh via existing radiology realtime paths after mutations or remote updates.
- AC5 (Req 9): English l10n and tests cover table layout, status→action flow, row→report dialog, undo, and non-nested chrome.

## Relevant Files

- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart`
- `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `frontend/lib/features/radiology/presentation/radiology_access.dart`
- `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`
- `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart` (flat row density reference)
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_collapsible_section.dart`
- `frontend/lib/shared/components/app_patient_details.dart`
- `backend/src/modules/radiology-workspace/`
- `backend/src/modules/radiology-order/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`
