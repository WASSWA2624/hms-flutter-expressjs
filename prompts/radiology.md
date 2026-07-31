# Radiology procedure workflow: simplify status actions

Simplify the Radiology workflow detail so **Procedure done** is a direct confirmation that imaging was performed—not a multi-step Start imaging → Assign → Perform study path. Remove Assign and Start imaging from this workbench. Support batch Procedure done for selected rows. Keep Cancel as a confirmed rich-text reason. After Procedure done, the next step is reporting (Create report), not another acquisition form.

## Context

- Detail / procedures workbench: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (`_RadiologyDetailBody`, `_ProcedureWorkbenchSection`, `_ProcedureDetailsDialog`).
- Current pain (see live detail, e.g. Grace Demo-Delta / `RAD0000006` Ankle and Foot X-Ray):
  - Patient header still shows **Assign** (opens Assign imaging order with assignee / schedule / room / equipment / notes) and **Start imaging**—extra steps nobody needs when any radiology-authorized user can perform the work.
  - **Procedure done** opens the **Perform imaging study** dialog (`_StudyForm` / `createStudy`) instead of simply marking the procedure done.
  - Cancel uses `_CancelForm` with two plain fields (cancellation reason + notes); product wants one rich-text reason with confirm.
  - No **Procedure done** for multiple selected procedure rows (select-all / Cancel selected exists; Done does not).
  - Procedure details already has status header + next-step copy; after Done it must steer clearly to **Create report** / reporting, not acquisition.
- Status model today: Pending → In process → Done — waiting for report → Reported / Cancelled (`_procedureWorkbenchStatus`).
- Mutations: `radiology_workspace_controller.dart` — `startImaging`, `assignOrder`, `createStudy`, `cancelOrder`, draft/finalize/report, undo.
- Backend: `backend/src/modules/radiology-workspace/` — start → `IN_PROCESS`; create study → performed study + waiting-for-report; cancel; draft/finalize results. Serializer `next_actions` (`can_start`, `can_assign`, `can_create_study`, `can_cancel`, …).
- Report dialog (keep): existing `_ReportEditDialog` (rich technique/findings/impression + images + print).
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppDialog` / `AppCollapsibleSection` / procedures table patterns.

## Requirements

1. **Remove Start imaging from this workbench:** Do not show **Start imaging** on the patient/order header (or elsewhere in this detail). Do not require a separate start step before Procedure done. If order status must become `IN_PROCESS` for the backend, fold that into Procedure done (or an equivalent single mutation)—do not keep a user-facing Start imaging control.

2. **Remove Assign from this workbench:** Do not show **Assign** on the patient header. Do not show **Assign typist** (or equivalent) on procedure rows / procedure details for this simplified flow. Do not open the Assign imaging order dialog from this workbench. Radiology-authorized writers who can work the procedure do not need an assignee gate here. Do not delete the assign API globally if other surfaces still use it—only remove it from this detail UX.

3. **Procedure done = mark done (no Perform study form):** Clicking **Procedure done** (row Actions, procedure details, or batch) must mark the procedure/order as done **without** opening `_StudyForm` / “Perform imaging study”. Prefer a single confirm (optional lightweight confirm dialog) then mutate. Internally reuse or extend the smallest safe path that creates/records the performed study (or equivalent) so status becomes **Done — waiting for report** everywhere the app reads radiology status. Default modality/room/equipment from the order when the API still requires them—do not ask the user again.

4. **Batch Procedure done:** With one or more procedure rows selected (checkbox / select-all), support **Procedure done** for the selection (header action next to Cancel selected, or equivalent). Mark all selected pending/in-process rows done in one confirm + mutation path (or sequential safe calls with clear progress/error). Disabled when selection is empty or none of the selected rows are eligible.

5. **After Procedure done → reporting next:** When status is waiting for report, procedure details (and row actions) must emphasize **Create report** / **Mark report done** (reuse existing comprehensive report dialog)—not Procedure done again. Procedure done means imaging/acquisition is complete so films/results can be picked up; it does **not** mean the report is released. Do not invent a second reporter.

6. **Cancel with rich-text reason:** Keep Cancel order / Cancel selected. Confirm with a dialog that uses a **single rich-text** cancellation reason (shared rich-text control already used in radiology reporting), not two separate plain reason + notes fields. Submit still calls existing `cancelOrder` (map rich text into the payload field(s) the API accepts—prefer one `reason` body; drop redundant notes UI). Require non-empty reason before submit.

7. **Keep the procedures table:** Preserve the flat table (# | checkbox | Procedure ID | Procedure | Modality | Body organ | Status | Actions), full-width section body, row → procedure details, and Cancel in Actions. Do not regress the polished procedure details header / info tiles / next-step panel—update next-step copy and buttons to match the simplified flow.

8. **Honest gating + realtime:** Keep write/print permission gates. Omit or disable Done/Cancel when not allowed. After Done / Cancel / report mutations, refresh selected workflow via existing radiology realtime / controller refresh so list and details do not stay stale.

9. **l10n + tests:** English strings for Create report (if new), batch Procedure done, cancel rich-text reason label/validation, updated next-step hints (pending / in process / waiting for report). Widget tests: no Start imaging / Assign on detail; Procedure done does not open Perform study form; batch Done marks selection; cancel dialog is single rich-text; after Done, details show reporting CTA; waiting-for-report status wording preserved.

Optional enhancements: none (do not redesign desk tabs, billing filters, or the report editor in this prompt).

## Constraints

- Reuse procedures table, `_ProcedureDetailsDialog`, report dialog, cancel mutation, and controller realtime refresh. Do not invent a second radiology desk.
- Prefer frontend UX simplification + wiring existing study/cancel/report APIs; only add the smallest backend helper if “mark done without study form” cannot reuse `createStudy` with defaults / combined start+study.
- No return of Request details / Timeline / Imaging floor–Reporting radios / nested procedure cards.
- Do not reintroduce billing gates that block Procedure done or reporting.
- Preserve undo for unreleased study/draft where already shipped, unless it conflicts with the new mark-done path—then keep undo for unreleased work only.

## Acceptance Criteria

- AC1 (Req 1–2): Radiology workflow detail has no Start imaging and no Assign / Assign typist / Assign imaging order entry points.
- AC2 (Req 3–4): Procedure done marks done without Perform study form; selected rows can be marked done together.
- AC3 (Req 5): After Done, status is waiting-for-report and UI offers Create report / Mark report done into the existing report dialog.
- AC4 (Req 6): Cancel confirm uses one rich-text reason (no dual reason+notes plain fields).
- AC5 (Req 7–9): Table + procedure details remain; English l10n and tests cover removals, direct Done, batch Done, cancel rich text, and reporting CTA.

## Relevant Files

- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart`
- `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `frontend/lib/features/radiology/presentation/radiology_access.dart`
- `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- `frontend/lib/features/radiology/domain/repositories/radiology_repository.dart`
- `frontend/lib/features/radiology/data/repositories/radiology_repository_impl.dart`
- `frontend/lib/shared/components/app_speech_to_text.dart` (rich text patterns used by report/cancel)
- `backend/src/modules/radiology-workspace/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`
