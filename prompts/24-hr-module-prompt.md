# Human Resources Module — Implementation Prompt

## Objective

Complete the **Human Resources (HR) Module** for HOSSPI HMS so HR staff and managers can run workforce administration end-to-end: staff profiles, positions, assignments, leave, availability, shift rosters, swap approvals, and payroll runs — supporting hospital operations that **enable** clinical modules without owning patient flows.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — HR module boundaries vs clinical and operational modules
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §13 role actions (staff must exist with correct roles for IPD workflows)
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 role teams (reception, nurse, doctor, billing) require rostered staff

**Module boundary:** HR owns staff records, assignments, shifts, rosters, leave, and payroll. HR does **not** mutate OPD/IPD encounters, patient records, or clinical orders. Clinical modules consume **user accounts and role assignments** created/maintained by HR and Users/Roles modules.

Deliver a **professional HR workspace**: staffing overview, work-item queues, roster generation/publish, and payroll preview/process.

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Use [opd-flow.mdc](../.cursor/flows/opd-flow.mdc) and [ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) for journey touchpoints; read the module-specific flow file when one exists (lab, nursing, pharmacy, radiology, discharge, emergency, icu, theater). |
| Encounters | One active OPD encounter per outpatient visit; IPD admission as inpatient hub; overlays (ICU, Theater) and executing departments attach — never parallel admission records. |
| UI/UX | Modern, clean, minimal on-screen text; hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `components.mdc`, `ui-patterns.mdc`, `ui-workspace.mdc`, `layouts.mdc`, `platform_guidelines.mdc`. Reuse `frontend/lib/shared/*` before creating new widgets. Responsive on Android, iOS, web, Windows, macOS, Linux. |
| Theming and i18n | Full theme support (light/dark/system). All user-visible strings in `app_en.arb` — no hardcoded labels. |
| Modal-first workflows | **All create/edit/approve/complete/handoff actions** use **in-page dialogs, bottom sheets, or nested modals**. Do **not** navigate to new routes for within-module workflows. Shell entry routes (`/opd`, `/ipd`, etc.) and deep-link **pre-selection** of a patient/record are allowed; selecting a row opens the workspace detail panel — not a separate workflow page. |
| Realtime sync | Subscribe to relevant `RealtimeEventGroups` in workspace controllers. After mutations, refresh affected rows, detail panels, summary cards, and nav badges. Keep UI, frontend state, backend services, and database consistent. |
| Architecture | UI/controllers → repository → API (`frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`). Enforce RBAC + ABAC + tenant/facility scope + module entitlements (frontend `AccessGate` + backend authorization). |
| Database | Apply migrations for schema changes per backend standards; keep API contracts and schema aligned. |
| Quality gate | From `frontend/`: `flutter pub get`, `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`. From `backend/`: targeted `npm test` for touched modules. |

---


## Relationship to OPD and IPD flows

HR does not implement patient flow stages. Integration is **indirect**:

| Flow reference | HR responsibility |
| -------------- | ----------------- |
| ipd-flow §13 roles | Ensure doctors, nurses, bed managers, cashiers, pharmacists have staff profiles, active assignments, and correct RBAC roles |
| opd-flow §5 teams | Provider schedules and availability support OPD doctor assignment and nurse vitals coverage |
| Ward/ICU staffing | Rosters and shift assignments align nursing coverage with ward workload (Nursing/IPD modules consume assigned staff as users) |
| Payroll | Operational — not on critical path for single patient flow |

When linking to billing for payroll deductions or stipends, see [prompts/09-billing-module-prompt.md](./09-billing-module-prompt.md) — HR does not own patient billing.

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/hr/` | Workspace page, controller, repository |
| HR workspace API | `backend/src/modules/hr-workspace/` | `GET /hr/workspace`, work-items, reference data |
| Legacy CRUD | `staff-profile`, `staff-assignment`, `staff-leave`, `shift-assignment`, `roster`, `payroll-run`, etc. | Hybrid workspace + granular APIs |
| Feature flag | `hr_workspace_v1` | Required for workspace routes |
| Backend tests | hr-workspace service/schema tests | Present |
| Localization | `app_en.arb` | HR workspace strings |

### Known gaps to close

- **Feature flag gating** — document enablement for dev/demo.
- **Roster ↔ clinical scheduling** — provider schedules for OPD not fully unified with HR rosters.
- **Work-item mutations** — approve/reject leave, swap, payroll from workspace UI completeness.
- **Module entitlement** — subscription key for HR module visibility.
- **Deep links** — `/hr?id=` query params.
- **Frontend tests** — expand beyond backend coverage.
- **Large page file** — extract widgets from `hr_workspace_page.dart`.

---

## Scope — Core Capabilities

### 1. Staff directory and profiles

- Searchable staff list with position, department, assignment status.
- Profile detail: contact, credentials, active assignments.

### 2. Work-item queues

- Leave requests, shift swaps, roster approvals, payroll items.
- Summary cards filter queues per workspace pattern.

### 3. Rosters and shifts

- Generate and publish rosters; shift overrides; assignment to units/wards where supported.

### 4. Leave and availability

- Approve/reject leave; staff availability for scheduling.

### 5. Payroll

- Preview and process payroll runs per policy; audit trail.

---

## UI / UX Requirements

- Workspace layout: `AppWorkspace` with summary cards (filter worklist), searchable list/table, detail panel, and modal action dialogs.
- Summary cards filter the board — they must not open separate list routes.
- Hide zero-value summary cards where the workspace pattern expects it.
- Show **next required action** and **responsible role** on worklist rows where applicable.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match Nursing, IPD, Lab, and OPD workspace patterns for consistency.

---


## Architecture and Conventions

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → Riverpod controllers → repository interface → impl → API client. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure` for errors. |
| Permissions | `AccessGate` / `AppAccessActionGate`; backend auth mandatory even when UI hides actions. |
| File size | Extract reusable widgets to `presentation/widgets/`; shared components to `frontend/lib/shared/`. |
| Realtime | `frontend/.cursor/realtime_sync.mdc` — partial refresh after modal success when supported. |

---


## Module Boundaries (do not violate)

From `../.cursor/app-write-up.mdc`:

- HR does not own patient registry, OPD queues, IPD admissions, or billing.
- Users/Roles module owns authentication accounts — HR staff profiles link to user accounts.
- Do not embed clinical workflows in HR workspace.

---

## Acceptance Criteria

- [ ] HR staff can manage profiles, rosters, leave, and payroll from workspace.
- [ ] Work items actionable with correct permissions.
- [ ] Staff with clinical roles appear assignable in OPD/IPD modules via user/role system.
- [ ] No patient-flow API calls from HR module.
- [ ] Feature flag and entitlements documented; tests pass.

---

## Quality Gate

From `frontend/` when touching Flutter:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="<module>"
```

Apply database migrations per backend workflow before merging schema changes.

---


## Key File References

```
frontend/lib/features/hr/
backend/src/modules/hr-workspace/
backend/src/modules/staff-profile/, roster/, payroll-run/

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md (role staffing context only)
```
