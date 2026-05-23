# Implementation Prompt: Normalize OPD Patient-Flow Status, Counts, Role Labels, and Actions

You are working on the HOSSPI Hospital Management System codebase with these main folders:

- `app-planner`
- `backend`
- `frontend`

Implement a focused OPD patient-flow fix so the OPD workspace displays patient status from the real patient/encounter state instead of blindly showing the last stored OPD stage.

## Core Problem

The OPD flow currently has multiple unsynchronized state sources:

- OPD flow stage
- encounter provider
- visit queue status
- triage route
- billing/payment state
- lab/radiology/pharmacy order state
- admission/discharge state

This causes wrong UI states such as **“Awaiting doctor assignment”** even when a doctor/provider is already assigned.

The main rule to implement is:

> OPD display status must be computed from the actual patient state, not copied directly from the stored OPD stage enum.

## Important Codebase Findings to Ground the Work

Use the current project structure and coding style as the source of truth.

### Backend OPD areas

Inspect and modify only where needed:

- `backend/src/modules/opd-flow/controllers/opd-flow.controller.js`
- `backend/src/modules/opd-flow/services/opd-flow.service.js`
- `backend/src/modules/opd-flow/repositories/opd-flow.repository.js`
- `backend/src/modules/opd-flow/routes/opd-flow.routes.js`
- `backend/src/modules/opd-flow/schemas/opd-flow.schema.js`
- `backend/src/config/roles.js`
- `backend/prisma/schema.prisma`

Also inspect connected modules only if required for synchronization:

- `backend/src/modules/triage/`**
- `backend/src/modules/triage-assessment/**`
- `backend/src/modules/visit-queue/**`
- `backend/src/modules/lab-order/**`
- `backend/src/modules/lab-result/**`
- `backend/src/modules/lab-sample/**`
- `backend/src/modules/radiology-order/**`
- `backend/src/modules/radiology-result/**`
- `backend/src/modules/pharmacy-order/**`
- `backend/src/modules/pharmacy-workspace/**`
- `backend/src/modules/admission/**`
- `backend/src/modules/bed-assignment/**`
- `backend/src/modules/billing/**`

Current backend issues to address:

- `opd-flow.repository.js` defaults OPD queries to both `OPD` and `EMERGENCY`.
- `opd-flow.service.js` has technical stages such as `WAITING_DOCTOR_ASSIGNMENT`, `LAB_REQUESTED`, `RADIOLOGY_REQUESTED`, `PHARMACY_REQUESTED`.
- `buildFlowSummary()` returns stage/next step but does not include assigned staff role/type.
- `NEXT_STEP_BY_STAGE` currently routes lab/radiology/pharmacy stages to `DISPOSITION`.
- `assignDoctor` accepts `provider_user_id` but does not strongly validate the assigned user role.
- `disposition` currently marks `ADMIT` as `ADMITTED` immediately.
- `SEND_TO_PHARMACY` can close/discharge the encounter before pharmacy dispensing is complete.
- `correct-stage` is currently available to nurse/doctor roles; it should be admin/supervisor-only based on existing role constants.

### Frontend OPD areas

Inspect and modify only where needed:

- `frontend/lib/features/opd/domain/entities/opd_entities.dart`
- `frontend/lib/features/opd/domain/repositories/opd_repository.dart`
- `frontend/lib/features/opd/data/dtos/opd_dtos.dart`
- `frontend/lib/features/opd/data/repositories/opd_repository_impl.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/shared/opd_actions/opd_action_context.dart`
- `frontend/lib/shared/opd_actions/opd_flow_actions_dialog.dart`
- `frontend/lib/shared/opd_actions/opd_provider_options.dart`
- `frontend/lib/shared/clinical_actions/clinical_action_items.dart`
- `frontend/lib/shared/clinical_actions/clinical_order_action_dialogs.dart`
- `frontend/lib/shared/clinical_actions/clinical_disposition_actions.dart`
- `frontend/lib/l10n/app_en.arb`
- `frontend/lib/l10n/app_localizations.dart`
- `frontend/lib/l10n/app_localizations_en.dart`
- `frontend/lib/l10n/app_localizations_x.dart`

Current frontend issues to address:

- `OpdFlowQuery` does not carry `encounter_type`.
- `opd_repository_impl.dart` calls `/opd-flows` without `encounter_type=OPD`.
- `OpdFlowSummary` does not include assigned staff role/type.
- `opd_workspace_page.dart` merges appointments, queues, triage, and active flows, then counts visible rows for summary cards.
- OPD status labels use `_apiLabel()` / raw enum formatting in several places.
- `_OpdPatientActionsDialog` shows many disabled downstream actions before they are relevant.
- `FlowActionsDialog` routes `LAB_REQUESTED`, `RADIOLOGY_REQUESTED`, `LAB_AND_RADIOLOGY_REQUESTED`, and `PHARMACY_REQUESTED` to disposition too early.
- UI strings still use generic “Provider” wording in OPD-facing areas.
- Procedure UI says **Request procedure**, but the backend records the procedure as performed.

### App planner references

Review these for architecture and flow intent:

- `app-planner/dev-plan/12-opd-flow.md`
- `app-planner/dev-plan/13-triage.md`
- `app-planner/dev-plan/14-clinical.md`
- `app-planner/dev-plan/21-lab.md`
- `app-planner/dev-plan/22-radiology.md`
- `app-planner/dev-plan/23-pharmacy.md`
- `app-planner/dev-plan/24-billing.md`
- `app-planner/dev-plan/16-inpatient.md`
- `frontend/app-planner/app-rules/`**
- `backend/app-planner/app-rules/**`

Do not edit planner files unless absolutely necessary.

No OPD task-specific screenshots were found in the archive. Do not assume screenshot-only requirements.

## Implementation Requirements

### 1. Add one central OPD state/display resolver

Create or refactor a central OPD resolver in the backend OPD module, following existing service/helper style.

It must compute the real OPD state from:

- consultation billing/payment state
- vitals state
- assigned staff/provider state
- assigned staff role/type
- lab order state
- radiology order state
- pharmacy order/dispensing state
- admission state
- encounter open/closed state
- discharge state

Use this resolver from all OPD mutation paths that can affect patient flow:

- OPD start/bootstrap/context update
- consultation payment
- vitals recording
- doctor assignment
- doctor review/order creation
- disposition
- triage routing if it updates OPD/encounter state
- lab/radiology/pharmacy completion hooks where existing module services update completion status

Do not create duplicate OPD flow systems.

### 2. Prevent incorrect “doctor needed” states

Never display or persist a patient as waiting for doctor assignment when a doctor/clinician is already assigned.

Expected behavior:


| Situation                                     | Correct OPD display                                   |
| --------------------------------------------- | ----------------------------------------------------- |
| consultation unpaid                           | Payment due                                           |
| payment done but vitals missing               | Vitals needed                                         |
| vitals done and no doctor assigned            | Doctor needed                                         |
| doctor assigned                               | With doctor or `Doctor: Name`                         |
| lab ordered and incomplete                    | Lab pending / Sample pending / In lab                 |
| lab result complete                           | Results ready                                         |
| radiology ordered and incomplete              | Imaging pending / Report pending                      |
| radiology report complete                     | Report ready                                          |
| medication prescribed but not dispensed       | Pharmacy pending                                      |
| medicine dispensed                            | Medicines dispensed / Decision needed, depending flow |
| ready for doctor final decision               | Decision needed                                       |
| admission requested but bed/IPD not confirmed | Admission pending                                     |
| IPD/bed allocation confirmed                  | Admitted                                              |
| OPD completed                                 | Discharged                                            |


### 3. Add role-aware assigned staff details to OPD responses

Extend OPD summary/detail response data so the frontend can display the assigned staff role/type.

Use existing user role/staff profile data. Verify the correct role source from:

- `user_role`
- `staff_profile`
- `practitioner_type`
- `position`
- existing role constants in `backend/src/config/roles.js`

Return enough data for the frontend to display:

- `Doctor: Jordan Demo`
- `Nurse: Sarah`
- `Lab Technician: Name`
- `Radiologist: Name` or `Radiology Technician: Name`
- `Pharmacist: Name`
- `Assigned staff: Name`
- `Assigned staff unknown`
- `Doctor needed` when no doctor is assigned and doctor assignment is required

Keep API responses backward-compatible where possible by adding fields instead of removing existing fields.

### 4. Validate or clarify doctor assignment

For the existing `assignDoctor` action:

- Validate that the assigned user is actually a doctor/clinician using existing roles/staff profile data.
- Do not allow nurses, lab techs, radiology techs, pharmacists, or unrelated staff to be assigned through a doctor-specific action.
- If the current codebase intentionally supports non-doctor clinical assignment through this same endpoint, rename OPD-facing UI wording to **Assign clinician** / **Assigned staff** and display the actual role everywhere. Do not leave misleading “doctor” labels for non-doctor staff.

Prefer minimal API disruption. Do not rename backend routes unless required.

### 5. Stop OPD/Emergency mixing

The OPD workspace must always query OPD records only.

Frontend:

- Update OPD flow queries to pass `encounter_type=OPD`.
- If an emergency workspace uses the same OPD flow API, ensure it passes `encounter_type=EMERGENCY`.

Backend:

- Ensure explicit `encounter_type` filters are respected.
- Do not mix OPD and EMERGENCY worklists unless a caller intentionally requests both.

### 6. Replace raw OPD enum labels with clear display labels

Create or use a central frontend OPD status display mapper.

Do not show raw enum-derived labels such as:

- `Waiting doctor assignment`
- `Waiting consultation payment`
- `Lab and radiology requested`

Use clear labels:


| Backend stage                  | Display requirement                                   |
| ------------------------------ | ----------------------------------------------------- |
| `WAITING_CONSULTATION_PAYMENT` | Payment due                                           |
| `WAITING_VITALS`               | Vitals needed                                         |
| `WAITING_DOCTOR_ASSIGNMENT`    | Doctor needed only if no doctor is assigned           |
| `WAITING_DOCTOR_REVIEW`        | With doctor / Doctor review                           |
| `LAB_REQUESTED`                | Lab pending / Sample pending / In lab / Results ready |
| `RADIOLOGY_REQUESTED`          | Imaging pending / Report pending / Report ready       |
| `LAB_AND_RADIOLOGY_REQUESTED`  | Compute display only: Lab & imaging pending           |
| `PHARMACY_REQUESTED`           | Pharmacy pending / Dispensing / Medicines ready       |
| `WAITING_DISPOSITION`          | Decision needed                                       |
| `ADMITTED`                     | Admitted only after actual admission confirmation     |
| `DISCHARGED`                   | Discharged                                            |


Use this mapper in:

- OPD status chips
- OPD table status column
- next-step labels
- OPD action context panel
- OPD detail/action dialogs
- OPD summary cards

Keep generic `_apiLabel()` for non-OPD values only where appropriate.

### 7. Fix OPD summary cards/counts

OPD summary cards must use backend aggregate counts, not the currently visible merged frontend table rows.

Implement or wire a backend-backed OPD count/summary source.

If an OPD summary endpoint already exists, use it. If it does not exist, add a small endpoint or extend the existing OPD list response in the `opd-flow` module, following existing API response patterns.

Required card definitions:


| Card              | Meaning                                                              |
| ----------------- | -------------------------------------------------------------------- |
| All Patients      | Total registered patients in the system                              |
| All OPD Patients  | Distinct patients who have OPD encounters                            |
| Active OPD        | Open OPD encounters only                                             |
| Vitals needed     | OPD patients waiting for vitals                                      |
| Doctor needed     | OPD patients without an assigned doctor                              |
| With doctor       | OPD patients assigned and awaiting/under doctor review               |
| Lab pending       | OPD patients with incomplete lab orders                              |
| Imaging pending   | OPD patients with incomplete radiology orders                        |
| Pharmacy pending  | OPD patients awaiting dispensing                                     |
| Decision needed   | OPD patients ready for final doctor disposition                      |
| Admission pending | OPD patients approved/requested for admission but not fully admitted |
| Discharged today  | OPD encounters discharged today                                      |


If any count cannot be reliably computed from the current schema, verify the missing source in the codebase and implement the closest safe backend-backed count without inventing fake data.

### 8. Fix OPD action menu clarity

In the OPD workspace:

- Show only valid next actions.
- Hide irrelevant disabled downstream actions.
- Do not show long disabled lists for appointment/queue rows before an active OPD encounter exists.
- Do not route lab/radiology/pharmacy stages directly to disposition.
- Determine next action from actual order state:
  - lab: collect sample, process lab, review result, results ready
  - radiology: perform imaging, complete/report imaging, report ready
  - pharmacy: dispense medicine, medicines dispensed
- If the OPD UI cannot safely perform the downstream action, show a clear valid handoff/status instead of exposing an incorrect disposition action.

Keep existing shared modal/action patterns. Do not create a new OPD board or duplicate action framework.

### 9. Fix pharmacy disposition behavior

`SEND_TO_PHARMACY` must not close/discharge the OPD encounter before pharmacy dispensing is complete.

Implement one of these safe behaviors, based on existing schema/workflow support:

- keep encounter open with `PHARMACY_REQUESTED` / `Pharmacy pending`, then close after dispensing is confirmed; or
- show a clear terminal display such as `Discharged – pharmacy pending` only if the existing workflow supports that distinction.

Do not make the patient disappear from OPD while medicines are still pending.

### 10. Fix admission behavior safely

OPD `ADMIT` should not mark the patient as fully admitted before IPD/bed allocation confirms admission.

Current Prisma `AdmissionStatus` appears to include `ADMITTED`, `DISCHARGED`, `TRANSFERRED`, and `CANCELLED`, with no obvious pending/requested value. Verify the existing IPD/bed workflow before changing schema.

Implement the safest supported behavior:

- display **Admission pending** after OPD admission request/approval;
- mark **Admitted** only after the existing IPD/bed workflow confirms admission;
- avoid unsafe schema changes unless they are required and fully migrated.

### 11. Restrict manual stage correction

Keep manual stage correction, but make it admin/supervisor-only.

Use existing role constants. If there is no explicit supervisor role, restrict to existing admin roles such as:

- `SUPER_ADMIN`
- `TENANT_ADMIN`
- `FACILITY_ADMIN`

Ensure correction remains audited with:

- old stage
- new stage
- reason
- acting user
- timestamp

Do not allow normal doctor/nurse users to hide workflow bugs by freely correcting stages.

### 12. Update OPD-facing wording

Replace generic **Provider** wording in OPD-facing UI where it causes confusion.

Use role-aware wording:


| Current wording   | Replacement                                                 |
| ----------------- | ----------------------------------------------------------- |
| Provider          | Assigned staff                                              |
| Provider assigned | Doctor assigned / Nurse assigned / Assigned staff           |
| Unknown provider  | Assigned staff unknown                                      |
| Search provider   | Search doctor or nurse / Search doctor, depending context   |
| Provider ID       | Staff ID                                                    |
| All providers     | All doctors / All clinicians / All staff, depending context |


Rename procedure UI wording:

- Replace **Request procedure** with **Record procedure** unless a true procedure request workflow exists.

Update localization files properly. Do not hard-code new UI strings in Dart widgets.

## Scope Limits

- Do not rewrite the whole OPD module.
- Do not create a second OPD workspace, board, route, or state system.
- Do not perform unrelated refactors.
- Do not change unrelated modules except where required to synchronize OPD state after lab/radiology/pharmacy/admission events.
- Do not invent statuses, enum values, API routes, or schema fields without verifying the existing codebase and migrations.
- Modify only the files required for this task.
- Preserve existing folder structure, naming conventions, code style, response format, validation patterns, Riverpod patterns, Flutter shared components, Express controller/service/repository structure, and Prisma conventions.

## Testing and Verification

Add or update tests where the project has an existing test pattern.

Backend verification:

- `assignDoctor` cannot leave a provider-assigned encounter in `WAITING_DOCTOR_ASSIGNMENT`.
- OPD list/query with `encounter_type=OPD` does not include emergency encounters.
- OPD summary/counts are backend-backed and not derived from visible frontend rows.
- OPD resolver returns correct display state for payment due, vitals needed, doctor needed, with doctor, lab pending/results ready, imaging pending/report ready, pharmacy pending/dispensed, decision needed, admission pending, admitted, and discharged.
- Pharmacy disposition does not close the OPD encounter before dispensing is complete.
- Admission flow does not display **Admitted** before IPD/bed confirmation.
- Stage correction is restricted and audited.

Frontend verification:

- OPD repository sends `encounter_type=OPD`.
- OPD status chips/table/actions use the central OPD display mapper instead of raw enum labels.
- Assigned staff/provider display is role-aware.
- Summary cards use backend aggregate counts.
- Disabled irrelevant downstream actions are hidden.
- Lab/radiology/pharmacy stages do not offer premature disposition as the next action.
- Procedure UI says **Record procedure**.

Run the relevant checks:

Backend:

```bash
cd backend
npm run lint
npm run test:backend
npm run openapi:validate
```

Frontend:

```bash
cd frontend
dart format .
flutter analyze
flutter test
```

If API contracts or localization generation require additional project-specific commands, run those too.

All linter/analyzer issues must be cleared before delivery.

## Final Delivery Format

Return a zipped archive containing only files and folders that were created or updated.

Requirements:

- Preserve correct relative project paths inside the zip.
- Do not include the full project.
- Do not include `node_modules`, build outputs, cache folders, logs, `.env`, screenshots, or unrelated files.
- Include updated tests when tests are changed or added.
- Include generated localization files only if this project expects them to be committed.

If any files or folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts in the archive to safely perform those operations.

PowerShell script requirements:

- Use correct relative paths.
- Use explicit file/folder targets only.
- Use `Test-Path` before deleting or renaming.
- Do not delete unrelated files.
- Do not use broad wildcards that could remove unrelated project files.

