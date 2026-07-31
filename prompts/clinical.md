# Clinical patient diagnoses

Improve the patient diagnoses section on clinical encounter details so clinicians can add, edit, and remove encounter diagnoses cleanly—with correct IDs, flat list rows, and primary/secondary/differential typing—without nested table chrome or leftover order-style columns.

## Context

- Details panel: `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart` (`ClinicalDiagnosesTablePanel`).
- Add dialog (dual-pane catalog): `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`.
- Workspace wiring / mutations: `clinical_workspace_page.dart`, `clinical_workspace_controller.dart`, `clinical_repository_impl.dart`.
- DTO mapping: `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart` (related records currently prefer `human_friendly_id` over UUID for non-note kinds).
- Backend: `backend/src/modules/diagnosis/` — `POST/PUT/DELETE /api/v1/diagnoses`; params use UUID-only `uuidSchema`. Model enum: `PRIMARY` | `SECONDARY` | `DIFFERENTIAL`.
- Current bugs/gaps: remove fails with “Enter a valid Id.” (friendly id sent to UUID route); no edit UI despite `PUT`; status/arrival columns are leftover and show `—` / timestamps; list is nested/padded like an extended table; type shown as raw enum.
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, and existing clinical action dialog patterns.

## Requirements

1. **Flat diagnoses list:** Render each diagnosis as an independent full-width row (edge to edge within the section). No nested/extended-table padding, inner cards, or indented child blocks between rows.
2. **Columns:** Show only the diagnosis content (name, humanized type, and code when present). Do **not** show Status or Arrival time.
3. **Display format:** Prefer `Name - Primary | CODE` (title-case type: Primary / Secondary / Differential). Omit the code segment when empty. Keep the row scannable on dense clinical layouts.
4. **Section header actions:** In the Patient diagnoses title bar, place an **Edit** action immediately left of the collapse chevron (same short generic label pattern as other clinical sections). Edit must open an edit-diagnosis flow that can change type (and description/code if already supported by API) for the selected diagnosis or open a clear multi-select edit path—do not leave Edit as a no-op.
5. **Remove (not Delete):** Row and confirm actions must use **Remove** wording (localized). Removing detaches/soft-removes the diagnosis from the active encounter record via the existing API; copy must not imply hard DB wipe. Confirm dialog title/body/buttons must say Remove.
6. **Fix remove id:** Ensure remove calls `DELETE /api/v1/diagnoses/:id` with the diagnosis **UUID** (`id`), not `human_friendly_id`. Fix DTO/list mapping for diagnoses (and any OPD reuse) so mutable clinical records expose UUID for write/delete while friendly ids remain for display if needed. Confirm the “Enter a valid Id.” path is gone.
7. **Add diagnosis types:** Keep (or refine) the dual-pane catalog picker. Clinicians must set **Primary**, **Secondary**, or **Differential** for the selection—applied to one diagnosis or to the whole selected group before commit. Persist `diagnosis_type` on create (and on edit).
8. **Uniqueness per encounter:** Do not allow the same catalog diagnosis (same code+description identity, or same clinical-term identity used today) more than once on the **same encounter**. Block duplicates in the picker and/or on submit with clear localized feedback. Different encounters may still share the same diagnosis.
9. **Edit dialog:** Implement an edit path that loads the existing diagnosis UUID and can update `diagnosis_type` (and fields already allowed by `PUT`). Reuse shared clinical dialog chrome/actions.
10. **l10n + tests:** English strings for Edit/Remove, confirm copy, duplicate-diagnosis errors, and type labels; widget/controller tests for flat list columns, remove-with-UUID, duplicate prevention, and edit opening with correct id/type.

Optional enhancements: none.

## Constraints

- Reuse shared clinical action dialogs, `AppDialog`, list/section patterns, and permissions (`CLINICAL_READ` / `CLINICAL_WRITE` / clinical delete privilege). Do not invent a parallel diagnoses module.
- Prefer fixing frontend id mapping for delete/edit; only widen backend params to friendly ids if product explicitly requires it—and then resolve to UUID in the repository.
- Do not reintroduce Status or Arrival time columns on this panel.
- No unrelated clinical refactors (vitals, notes, orders) beyond diagnoses list/add/edit/remove.
- Preserve OPD reuse of the shared diagnosis dialog if it already depends on the same contract.

## Acceptance Criteria

- AC1 (Req 1–3): Diagnoses section shows flat full-width rows with diagnosis-only content; no Status/Arrival columns; type is humanized.
- AC2 (Req 4, 9): Title-bar Edit opens a working edit flow bound to the diagnosis UUID.
- AC3 (Req 5–6): Remove confirm uses Remove copy; remove succeeds without “Enter a valid Id.”
- AC4 (Req 7–8): Add supports Primary/Secondary/Differential per selection/group; duplicate diagnosis on the same encounter is blocked with feedback.
- AC5 (Req 10): English l10n and tests cover list, remove UUID, duplicates, and edit.

## Relevant Files

- `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart`
- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
- `frontend/lib/features/clinical/data/dtos/clinical_dtos.dart`
- `frontend/lib/features/clinical/data/repositories/clinical_repository_impl.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_diagnosis_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_action_dialog_helpers.dart`
- `backend/src/modules/diagnosis/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
