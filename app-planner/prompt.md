You are working on the attached Hospital Management System codebase with these main folders:

* `app-planner`
* `backend`
* `frontend`

Your task is to inspect the existing codebase and implement targeted fixes that make the OPD and IPD patient flows clear, consistent, simple, backend-aligned, role-aware, and free of confusing or redundant steps.

Do **not** perform a broad rewrite. Implement only the changes required to fix real issues found in the existing code.

---

## 1. Main Problem to Solve

Review and improve the complete OPD and IPD flows so that:

* Patient movement through OPD and IPD is obvious and complete.
* Frontend workflow steps match backend stages, routes, permissions, and data models.
* Redundant, duplicated, unclear, or frontend-only steps are removed or corrected.
* Role-based menus and pages show only what each user is authorized to access.
* OPD/IPD actions are available only to the correct roles.
* Bottlenecks, unnecessary reloads, inconsistent status labels, and confusing UI states are fixed.
* Linter/analyzer issues are cleared.

The final system should feel like a professional hospital workflow: simple for users, strict on permissions, and aligned across frontend, backend, and planner documentation.

---

## 2. Project Areas to Inspect

Inspect these areas before modifying anything.

### `app-planner`

Review and use these files as planning references:

* `app-planner/prompt.md`
* `app-planner/opd-flow.md`
* `app-planner/ipd-flow.md`
* `app-planner/dev-plan/12-opd-flow.md`
* `app-planner/dev-plan/16-inpatient.md`
* `app-planner/dev-plan/19-discharge.md`

Important: `app-planner/dev-plan/12-opd-flow.md` refers to `app-planner/opd-flow.md` as an OPD source of truth, but the current `opd-flow.md` may contain older summary-card instructions instead of a complete OPD flow blueprint. Verify this mismatch from the actual file content. If planner files are updated, update only the relevant planner files and keep them aligned with the implemented code.

No separate workflow screenshots are present in the archive. Use the existing Flutter UI patterns and planner documents as the UI/UX source of truth.

### Backend

Inspect these backend areas:

* `backend/src/app/router.js`
* `backend/src/config/roles.js`
* `backend/src/config/permissions.js`
* `backend/src/modules/opd-flow/**`
* `backend/src/modules/ipd-flow/**`
* `backend/src/modules/admission/**`
* `backend/src/modules/encounter/**`
* `backend/src/modules/visit-queue/**`
* `backend/src/modules/triage/**`
* `backend/src/modules/patient/**`
* `backend/src/modules/appointment/**`
* `backend/src/modules/billing/**`
* `backend/src/modules/invoice/**`
* `backend/src/modules/payment/**`
* `backend/src/modules/lab-workspace/**`
* `backend/src/modules/radiology-workspace/**`
* `backend/src/modules/pharmacy-workspace/**`
* `backend/src/modules/clinical-note/**`
* `backend/src/modules/nursing-note/**`
* `backend/src/modules/discharge-summary/**`
* `backend/src/modules/bed/**`
* `backend/src/modules/bed-assignment/**`
* `backend/src/modules/transfer-request/**`
* `backend/src/modules/icu-stay/**`
* `backend/scripts/seeders/seed-catalog.js`

Preserve the backend architecture:

* Express + CommonJS.
* `/api/v1/*` routes.
* Route → controller → service → repository layering.
* Zod validation.
* Existing response helpers.
* Existing role/permission system.
* Existing Prisma/database naming conventions.
* Existing audit/security patterns.

### Frontend

Inspect these frontend areas:

* `frontend/lib/app/router/app_routes.dart`
* `frontend/lib/app/router/app_router.dart`
* `frontend/lib/app/router/route_guards.dart`
* `frontend/lib/core/permissions/**`
* `frontend/lib/features/opd/**`
* `frontend/lib/features/ipd/**`
* `frontend/lib/features/patients/**`
* `frontend/lib/features/clinical/**`
* `frontend/lib/features/nursing/**`
* `frontend/lib/features/lab/**`
* `frontend/lib/features/radiology/**`
* `frontend/lib/features/pharmacy/**`
* `frontend/lib/features/billing/**`
* `frontend/lib/features/discharge/**`
* `frontend/lib/features/emergency/**`
* `frontend/lib/features/icu/**`
* `frontend/lib/features/rooms_beds/**`
* `frontend/lib/shared/layout/app_workspace.dart`
* `frontend/lib/shared/components/app_list_table.dart`
* `frontend/lib/shared/components/app_search_bar.dart`
* `frontend/lib/shared/opd_actions/**`
* `frontend/lib/l10n/**`, if UI text is changed

Preserve the frontend architecture:

* Flutter feature-first structure.
* Riverpod state management.
* GoRouter route guards.
* Existing shared layout/components.
* Existing localization approach.
* Existing styling, spacing, cards, tables, dialogs, badges, and workspace patterns.

---

## 3. OPD Flow Requirements

Make the OPD flow simple, complete, and backend-aligned.

The OPD flow must support these entry paths where already represented in the codebase:

* Walk-in/new patient.
* Appointment check-in.
* Follow-up/review.
* Emergency-to-OPD handoff where applicable.

The OPD flow must avoid duplicate active encounters. If an active OPD encounter already exists for a patient, the UI should reuse or clearly surface it instead of silently creating another one.

The frontend OPD workspace must align with backend OPD flow stages, including:

| Backend OPD Stage              | Expected User Meaning                                       | Expected Primary Owner |
| ------------------------------ | ----------------------------------------------------------- | ---------------------- |
| `WAITING_CONSULTATION_PAYMENT` | Patient must complete consultation/payment gate if required | Reception/Billing      |
| `WAITING_VITALS`               | Patient is ready for vitals                                 | Nurse                  |
| `WAITING_DOCTOR_ASSIGNMENT`    | Patient needs doctor/provider assignment                    | Reception/Nurse        |
| `WAITING_DOCTOR_REVIEW`        | Patient is waiting for consultation                         | Doctor                 |
| `LAB_REQUESTED`                | Patient has pending lab work                                | Lab                    |
| `RADIOLOGY_REQUESTED`          | Patient has pending imaging                                 | Radiology              |
| `LAB_AND_RADIOLOGY_REQUESTED`  | Patient has pending diagnostics                             | Lab/Radiology          |
| `PHARMACY_REQUESTED`           | Patient has pending pharmacy action                         | Pharmacy               |
| `WAITING_DISPOSITION`          | Doctor must decide final outcome                            | Doctor                 |
| `ADMITTED`                     | Patient has moved to IPD/admission flow                     | OPD/IPD handoff        |
| `DISCHARGED`                   | OPD visit is complete                                       | Reception/Clinical     |

Fix any frontend labels, filters, actions, badges, summary cards, or dialogs that do not match the backend meaning.

OPD worklists must clearly show:

* Patient identity.
* Encounter/visit information.
* Visit type.
* Queue/stage/status.
* Provider or department.
* Billing/payment state where relevant.
* Waiting time or arrival time where available.
* Next required action.
* Role/team responsible for the next action.

OPD actions must be shown only when valid for the current stage and current user role. Do not show doctor review actions to billing users, billing actions to lab users, clinical actions to reception-only users, or staff actions to patient users.

Avoid full workspace reloads after small modal actions if existing controller patterns support targeted refresh.

---

## 4. IPD Flow Requirements

Make the IPD flow simple, complete, and backend-aligned.

The IPD flow should follow the existing planner intent:

1. Admission request from OPD, emergency, planned admission, or referral.
2. IPD admission/encounter creation.
3. Bed request and allocation.
4. Configurable billing/insurance clearance where already supported.
5. Ward handover.
6. Nursing admission.
7. Doctor inpatient assessment.
8. Care plan, orders, notes, and service execution.
9. Transfers where needed.
10. Discharge planning.
11. Final clinical, nursing, pharmacy, billing, and insurance clearance where supported.
12. Patient exit.
13. Bed cleaning/release.
14. Encounter closure.

The frontend IPD workspace must align with backend IPD flow stages, including:

| Backend IPD Stage      | Expected User Meaning                     | Expected Primary Owner         |
| ---------------------- | ----------------------------------------- | ------------------------------ |
| `ADMITTED_PENDING_BED` | Admission exists but bed is not assigned  | Bed manager/Nurse/Operations   |
| `ADMITTED_IN_BED`      | Patient is admitted and assigned to a bed | Ward/Nursing/Doctor            |
| `TRANSFER_REQUESTED`   | Transfer has been requested               | Ward/Operations                |
| `TRANSFER_IN_PROGRESS` | Transfer is being processed               | Ward/Operations                |
| `DISCHARGE_PLANNED`    | Discharge is planned but not finalized    | Doctor/Nurse/Billing/Pharmacy  |
| `DISCHARGED`           | Admission is complete                     | Clinical/Billing/Operations    |
| `CANCELLED`            | Admission was cancelled/rejected          | Authorized admin/clinical user |

Fix any frontend labels, filters, actions, badges, summary cards, or dialogs that do not match the backend meaning.

IPD worklists must clearly show:

* Patient identity.
* Admission number/context.
* Current ward/room/bed.
* Admission stage.
* Transfer status where relevant.
* Discharge status where relevant.
* ICU status where relevant.
* Next required action.
* Role/team responsible for the next action.

Verify the current backend IPD permissions. The IPD planner expects bed, ward, nursing, operations, billing, and clinical users to participate in the flow, but the current backend IPD routes may be restricted mostly to clinical permissions. Align backend and frontend access rules if this creates blocked or inconsistent workflow behavior.

---

## 5. Role-Based Menu and Access Requirements

For every authenticated user, the sidebar/menu, route guards, visible pages, buttons, dialogs, and backend endpoints must agree.

Verify these demo accounts from the seed data and raw task:

* `super.admin@hosspi.com`
* `tenant.admin@hosspi.com`
* `facility.admin@hosspi.com`
* `doctor@hosspi.com`
* `nurse@hosspi.com`
* `lab@hosspi.com`
* `pharmacy@hosspi.com`
* `reception@hosspi.com`
* `billing@hosspi.com`
* `operations@hosspi.com`
* `hr@hosspi.com`
* `biomed@hosspi.com`
* `housekeeping@hosspi.com`
* `ambulance@hosspi.com`
* `patient.portal@hosspi.com`

Also verify `radiology@hosspi.com` if it exists in the seed data.

Required behavior:

* Users must see only menu items and pages they are authorized to access.
* Route guards must block unauthorized deep links.
* Backend endpoints must reject unauthorized actions.
* Frontend and backend role/permission mappings must remain mirrored.
* Patient users must not access staff OPD/IPD/clinical/admin workspaces.
* Housekeeping users must not access clinical OPD/IPD workspaces unless explicitly allowed by the permission model.
* Lab users should access lab/diagnostic work, not unrelated OPD/IPD clinical actions.
* Pharmacy users should access pharmacy work, not unrelated OPD/IPD clinical actions.
* Billing users should access billing/payment/claims and payment-gate actions only.
* Reception users should access patient registration, appointment/check-in, queue, and reception-level OPD actions only.
* Doctors and nurses should access clinical/nursing actions appropriate to their roles.
* Operations users should access operational flow areas only where permissions and backend routes allow.
* Admin users should retain appropriate broad access.

If the exact intended page set for a role is unclear, derive it from:

1. `backend/src/config/permissions.js`
2. `frontend/lib/core/permissions/access_policy.dart`
3. `frontend/lib/app/router/app_routes.dart`
4. Existing seed roles in `backend/scripts/seeders/seed-catalog.js`

Do not invent new permissions or modules unless required to resolve a real backend/frontend mismatch.

---

## 6. UI/UX Requirements

Use the existing UI patterns. Do not introduce a new design system.

OPD/IPD screens should continue using the established HMS workspace style:

* `AppWorkspace`
* Compact summary cards.
* `AppListTable`
* Search/filter controls.
* Status badges.
* Detail panels.
* Focused dialogs/modals for actions.
* Existing responsive/mobile behavior.
* Existing sidebar grouping and visual hierarchy.

Improve clarity by ensuring:

* Every patient row has a clear status and next action.
* Every action label uses hospital workflow language, not technical stage names.
* Empty states explain what the user should do next.
* Disabled or hidden actions are consistent with permissions.
* Summary cards filter the current worklist when clickable.
* Summary cards do not point to empty or misleading filters.
* Zero-value cards should be hidden only where the existing design/prompt pattern expects that behavior.
* Similar statuses use consistent colors, labels, and badge styles across OPD/IPD.
* Avoid duplicate buttons that perform the same step.
* Avoid multi-step navigation when a focused modal is enough.
* Do not display backend enum names directly to normal users unless that is already the project convention.

---

## 7. Specific Implementation Requirements

Implement fixes in the minimum number of files required.

You must:

1. Audit current OPD and IPD frontend flows against backend services and routes.
2. Fix any mismatched status/stage labels.
3. Fix any role-visible actions that the backend would reject.
4. Fix any backend route permissions that block required real workflow participants.
5. Fix any frontend route/menu permissions that expose unauthorized pages.
6. Fix confusing OPD/IPD filters, summary cards, or worklist counts if they are inconsistent.
7. Fix duplicated or redundant patient-flow actions where the same step appears in multiple confusing places.
8. Ensure OPD-to-IPD handoff is clear where admission/disposition already exists.
9. Ensure IPD discharge/bed-release behavior is clear and aligned with existing discharge/bed modules.
10. Update localization files if UI text changes.
11. Update planner files only when needed to keep source-of-truth documentation aligned.
12. Add or update tests where existing project patterns support it.

Do not:

* Rewrite unrelated modules.
* Replace the app shell.
* Replace Riverpod/GoRouter architecture.
* Bypass backend service/repository layers.
* Add new global state systems.
* Add duplicate OPD/IPD dashboards.
* Change database schema unless absolutely necessary.
* Change seeded accounts unless required to fix role/access mismatches.
* Modify files outside the requested task.
* Add screenshots, build outputs, dependency folders, logs, or generated junk files.

---

## 8. Testing and Verification

Run relevant checks and fix all issues before packaging.

Backend:

```bash
cd backend
npm run lint
npm run test:backend
npm run openapi:validate
```

If backend routes/schemas/OpenAPI output are changed, also run the project’s OpenAPI generation/validation flow according to existing scripts.

Frontend:

```bash
cd frontend
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

If integration tests are already used for navigation/access smoke testing, update and run:

```bash
flutter test integration_test
```

Verify manually or with tests that:

* Each listed account sees only authorized menu items.
* Unauthorized deep links are blocked.
* OPD actions match current stage and role.
* IPD actions match current stage and role.
* OPD/IPD frontend calls match backend routes.
* No linter/analyzer errors remain.
* No obvious performance regressions are introduced.
* No full-page refresh is used where an existing targeted refresh pattern is available.

---

## 9. Scope Limits

This is a targeted implementation task, not a full product redesign.

Keep changes limited to:

* OPD flow clarity.
* IPD flow clarity.
* Role/menu/page/action access consistency.
* Backend/frontend permission alignment.
* UI consistency directly related to OPD/IPD and patient-flow navigation.
* Planner documentation updates only where needed.

Do not fix unrelated features discovered during review unless they directly block OPD/IPD flow correctness or role access.

If a requirement is incomplete or unclear, preserve the known behavior, implement the safest codebase-aligned fix, and mark the unresolved detail in a small code comment only where necessary.

---

## 10. Required Final Deliverable

Return a zipped archive containing **only** files and folders that were created or updated.

Requirements for the zip:

* Preserve correct relative project paths.
* Include only changed/new files.
* Do not include the full repository.
* Do not include `node_modules`, Flutter build folders, generated build artifacts, logs, `.env` files, caches, or unrelated files.
* If files/folders must be deleted or renamed, include one or more `.ps1` PowerShell scripts that safely perform those operations.
* `.ps1` scripts must use correct relative paths.
* `.ps1` scripts must not delete unrelated files.
* Ensure all linter/analyzer issues are cleared before returning the archive.
