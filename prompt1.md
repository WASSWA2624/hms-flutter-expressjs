# Task: Complete HR workforce administration capabilities

## Goal

Review and extend the **Human Resources (HR) workspace** so HR managers can administer staff end-to-end from one module: onboard staff, assign roles and module access, attach staff to one or more departments, set compensation, and create or approve work schedules — including reusable schedule templates.

All workflows stay **inside the HR module** using in-page dialogs, bottom sheets, or nested modals (no separate route navigation for CRUD or approvals).

## Context

HR is a **workforce administration module**, not a clinical module. It owns staff profiles, assignments, shifts, rosters, leave, and payroll. Clinical modules (OPD, IPD, etc.) consume **user accounts and role assignments** that HR maintains; HR does not mutate patient records or encounters.

**Platform standards** (theming, i18n, architecture, RBAC, realtime, quality gate) are defined in [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md). Follow that document for global rules; this prompt focuses on the product capabilities described below.

**Current implementation** (read before changing code):

| Area | Location | Status |
| ---- | -------- | ------ |
| HR workspace UI | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` | Staff directory, detail panel, work queues, modal CRUD |
| Controller / API | `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`, `backend/src/modules/hr-workspace/` | Workspace load, mutations, reference data |
| Staff CRUD | Add/edit staff dialog | Create links to existing `user_id`; edit profile fields |
| Department assignment | Assign department dialog | Adds `staff_assignment` rows; detail shows assignment list |
| Position / title | Assign position dialog | Updates staff position |
| Compensation | Compensation dialog + detail section | Pay types: `PER_HOUR`, `PER_MONTH`, `PER_PROCEDURE` |
| Scheduling | Availability, shift assign, shift swap, roster drafts | Shift templates in reference data (`shift_templates`) |
| Work queues | Leave, swaps, roster drafts, unassigned shifts, payroll drafts | Approve/reject actions partially wired |
| Roles reference data | `HrReferenceData.roles` | Loaded from API; **no staff role-assignment UI yet** |
| Users / access admin | `frontend/lib/features/access_admin/` | Owns user creation, role assignment, role permissions |

Feature flag: `hr_workspace_v1`. Dev entry: `.\frontend\tool\run_web_5201.ps1` → `/hr`.

## Problem / Gaps

The HR workspace scaffold exists but does not yet fully match the intended HR manager workflow:

1. **Staff onboarding** — HR can add staff linked to an existing user ID, but cannot create a user account or assign initial roles from HR in one flow.
2. **Roles and module access** — A staff member may need **one or more roles** and rights to access specific modules; reference data includes roles, but the workspace lacks actions to assign/revoke roles or grant module entitlements from the staff detail panel.
3. **Multi-department membership** — Backend supports multiple `staff_assignment` rows; UI should make add/view/end assignments clear (primary department vs additional assignments).
4. **Compensation models** — Hourly, monthly, and per-procedure rates exist; clinical pay models such as **per task**, **per review**, or **per procedure performed** (e.g. doctors) may need additional pay types and clearer UI.
5. **Work schedules** — Individual shift assignment and roster drafts exist; **predefined schedule templates** (define once, attach to nurses or other staff) need a complete create → attach → approve/publish flow.
6. **Action discoverability** — Staff detail `AppActionSection` should expose all HR actions with correct `AccessGate` permissions and localized labels.

## Requirements

### 1. Staff and user onboarding

- HR can **add new staff** and **edit existing staff** from the workspace (modal dialogs).
- Support linking to an existing user account **and/or** initiating user creation where product boundaries allow (coordinate with Users/Roles module — do not duplicate auth logic).
- Display staff number, name, position, departments, hire date, and linked user in the detail overview.

### 2. Roles and module access

- HR can **assign one or more roles** to a staff member's linked user account.
- HR can grant **module access rights** (entitlements) so staff can use specific modules (e.g. OPD, IPD, Lab).
- Show current roles and effective module access on the staff detail panel; changes via modal actions, not new routes.
- Enforce RBAC + ABAC on both frontend (`AccessGate`) and backend authorization.

### 3. Positions, titles, and departments

- HR can set or change a staff member's **position / title**.
- HR can attach a staff member to **one or more departments** (and unit/room where applicable).
- Assignment list in detail shows active and historical assignments with start/end dates.
- Primary department shown in directory columns; additional assignments visible in detail.

### 4. Payroll and compensation

- Per staff member, HR can configure **how they are paid**:
  - Per hour
  - Per month (salary)
  - Per procedure / per task / per review (variable clinical compensation)
- Support multiple active compensation rows with effective dates and currency.
- Payroll run preview/process remains in HR work queues; compensation changes reflect in payroll calculations.

### 5. Work schedules and rosters

- HR can **create work schedules** for individual staff (e.g. a specific nurse).
- HR can define **predefined schedule templates** and attach them to one or more staff members.
- HR can **create and approve** rosters / schedules from work queues (draft → approve/publish).
- Shift templates, availability, shift assignment, and swap request flows should work together consistently.

### 6. Module-first UX (mandatory)

- **All actions** (create, edit, assign, approve, complete) open as **dialogs, bottom sheets, or nested modals** within `/hr`.
- Do **not** navigate to separate workflow pages for within-module operations.
- Nested modals are allowed for multi-step flows (e.g. roster publish, payroll process).
- After successful mutations, refresh staff rows, detail panel, summary cards, and work queues (realtime where supported).

## Out of scope

- Patient registry, OPD/IPD encounter workflows, or clinical orders in the HR module.
- Replacing the Users/Roles admin module — integrate or deep-link where appropriate instead of duplicating.
- Visual redesign of shared components (`AppDialog`, `AppWorkspace`) unless required for HR flows.
- Breaking changes to unrelated modules.

## Key files

```
frontend/lib/features/hr/
  presentation/pages/hr_workspace_page.dart      — primary UI; staff actions & dialogs
  presentation/controllers/hr_workspace_controller.dart
  domain/entities/hr_entities.dart
  data/repositories/hr_repository_impl.dart

backend/src/modules/hr-workspace/
backend/src/modules/staff-profile/, staff-assignment/, roster/, payroll-run/

Related (roles / users):
frontend/lib/features/access_admin/
backend/src/modules/user/, role/

Standards: prompts/24-hr-module-prompt.md, frontend/.cursor/ui-workspace.mdc
```

## Acceptance criteria

- [ ] HR can add and edit staff from the workspace without leaving `/hr`.
- [ ] HR can assign **one or more roles** and **module access rights** to a staff member from staff detail actions.
- [ ] HR can assign **one or more departments**; detail panel lists all assignments.
- [ ] HR can set position/title and compensation (hourly, monthly, and variable/clinical pay types as supported by schema).
- [ ] HR can create individual schedules and use **predefined templates** attached to staff.
- [ ] HR can create and approve work schedules / rosters from work queues.
- [ ] All CRUD and approval actions use modals or nested modals — no new routes for within-module workflows.
- [ ] Permissions enforced in UI and API; strings localized in `app_en.arb`.
- [ ] `flutter analyze` and relevant HR tests pass.

## Suggested approach

1. **Audit** `hr_workspace_page.dart` — map each requirement above to existing dialogs/actions; list missing actions (roles, module access, template CRUD, pay types).
2. **Backend** — extend hr-workspace mutations or reuse Users/Roles APIs for role and entitlement assignment; add pay types to schema if `PER_TASK` / `PER_REVIEW` are required.
3. **Staff detail actions** — add `AppPermissionActionItem` entries for assign roles, manage module access, manage schedule templates; gate with existing HR write / roster / payroll requirements.
4. **Multi-assignment UX** — improve assignment section (add/end assignment) without collapsing multiple departments into a single field.
5. **Schedule templates** — CRUD for shift/schedule templates in modal; attach template to staff via shift assignment or roster generation.
6. **Verify** manually at `/hr`: add staff → assign departments & roles → set compensation → create schedule from template → approve roster draft.
7. **Tests** — controller/repository tests for new mutations; widget tests for critical dialogs if feasible.

## Deliverable

A focused update to the HR workspace (frontend + backend as needed) that closes the gaps above while respecting module boundaries and the modal-first workspace pattern defined in the HR module prompt.
