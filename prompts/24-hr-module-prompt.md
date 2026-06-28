# Human Resources Module — Comprehensive Implementation Prompt

## Objective

Complete the **Human Resources (HR) Module** for HOSSPI HMS so HR managers and workforce administrators can run hospital staffing end-to-end from one professional workspace: onboard staff, assign roles and module access, attach staff to departments and units, configure compensation, manage leave and availability, create and approve work schedules (including reusable templates), generate and publish rosters, and preview/process payroll — **enabling** clinical and operational modules without owning patient flows.

Deliver a **production-ready HR workspace** at `/hr`: staff directory, modal-first detail and mutations, labeled work queues, roster lifecycle, payroll preview/process — permission-gated, realtime-aware, and visually consistent with peer admin modules (Users/Roles, Subscriptions, Operations).

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — HR module scope vs clinical and operational modules; demo seed expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 role teams require rostered staff with correct RBAC
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §13 key IPD actions by role
4. [flows/nursing-flow.mdc](../.cursor/flows/nursing-flow.mdc) — ward nursing coverage depends on shift rosters
5. [prompts/04-access-admin-module-prompt.md](./04-access-admin-module-prompt.md) — Users/Roles owns auth accounts and permission matrices; HR links staff to users
6. [prompts/02-subscriptions-module-prompt.md](./02-subscriptions-module-prompt.md) — `hr-rosters` entitlement gates HR workspace visibility

**Companion focused prompts (execute in order when doing UI work):**

| Prompt | Scope |
|--------|--------|
| [prompt2.md](../prompt2.md) | Shared `AppDialog` resize and true viewport maximize |
| [prompt1.md](../prompt1.md) | HR toolbar, work queues, staff detail layout, notifications submenu |

**Central workforce rule:** every staff profile, assignment, shift, roster, leave record, and compensation row attaches to **tenant/facility scope** and links to a **user account** when the person needs system access. HR does **not** mutate OPD/IPD encounters, patient records, clinical orders, or patient billing. Clinical modules consume **user accounts, role assignments, and rostered availability** maintained by HR (and Users/Roles).

---

## Global Implementation Standards

Mandatory platform rules for all work in this module.

| Area | Requirement |
| ---- | ----------- |
| Product scope | [app-write-up.mdc](../.cursor/app-write-up.mdc) — respect module boundaries; do not duplicate workflows owned elsewhere. |
| Patient flows | Align with [`.cursor/flows/`](../.cursor/flows/). Read OPD/IPD/nursing flow files before staffing changes. |
| UI/UX | Hospital workflow language (not enum names or UUIDs). Follow `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`, `layouts.mdc`. Reuse `frontend/lib/shared/*`. Responsive on all platforms. |
| Theming and i18n | Light/dark/system themes. All user-visible strings in `app_en.arb`. |
| Modal-first | All create/edit/approve/process actions use dialogs or nested modals — no workflow sub-routes. Shell route `/hr` and query pre-selection (`?id=`, `?queue=`, `?search=`) only. |
| Realtime sync | Subscribe to HR `RealtimeEventGroups`; refresh rows, detail, summary counts, and nav badges after mutations. |
| Architecture | Widgets → Riverpod controllers → repository → API. RBAC + ABAC + tenant/facility scope + module entitlements. |
| Quality gate | `flutter analyze`, `flutter test`, targeted backend `npm test` for touched HR modules. |

---

## Flow Integration Requirements

HR does not implement patient flow stages. Integration is **indirect** — HR ensures the right people exist, are authorized, and are scheduled.

### OPD flow ([opd-flow.mdc](../.cursor/flows/opd-flow.mdc) §5)

| OPD concept | HR responsibility |
| ----------- | ----------------- |
| Reception / nurse / doctor / billing / lab / radiology / pharmacy teams | Staff profiles, roles, module entitlements, rosters, availability |
| Provider assignment | OPD consumes staff marked available with clinical roles — HR rosters must align |

### IPD flow ([ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) §13)

| IPD role | HR responsibility |
| -------- | ------------------- |
| Admission desk, bed manager, ward nurse, doctor, cashier, pharmacy, lab, radiology, OT | Correct roles and facility scope; shift coverage; swap/leave gaps flagged |
| Housekeeping | Not owned by HR — may share staff directory for non-clinical staff |
| Admin | Users/Roles configures; HR does not replace tenant/facility admin |

### Nursing flow ([nursing-flow.mdc](../.cursor/flows/nursing-flow.mdc))

Assigned ward nurses appear as users with nursing role; shift assignments traceable at handover time.

### Users/Roles and subscriptions

| Concept | HR responsibility |
| ------- | ------------------- |
| User accounts | Staff profiles **link** to users; creation may delegate to Access Admin or HR onboarding modal |
| Role assignment | HR assigns roles via `user_role`; backend is source of truth |
| Module entitlements | Subscription flags determine menu visibility; HR shows effective access on staff detail |
| Permission editing | Read-only preview in HR; matrix editing stays in Access Admin |

### Recommended journeys

**Staff onboarding:** Add profile → link/create user → assign roles → set position/departments → compensation → availability/shifts.

**Roster lifecycle:** Define template → create draft → generate assignments → review coverage → approve → publish + notify.

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/hr/` | `data/`, `domain/`, `presentation/` layers |
| Workspace UI | `hr_workspace_page.dart` (~3.5k lines) | Staff directory, staff-detail dialog, work-queue dialog, activity dialog, inline CRUD |
| Enhanced dialogs | `presentation/widgets/hr_enhanced_dialogs.dart` | Assign role, module access, create user, shift template, roster/payroll preview, end assignment |
| Controller | `hr_workspace_controller.dart` | Load, filter, select staff, queue filters, mutations, deep-link query |
| Repository | `hr_repository_impl.dart` | Workspace, reference data, staff CRUD, assignments, leave, availability, shifts, swaps, roster, payroll |
| HR workspace API | `backend/src/modules/hr-workspace/` | `GET /hr/workspace`, `/work-items`, `/reference-data`; coordinated actions |
| Legacy CRUD APIs | `staff-profile`, `staff-assignment`, `staff-leave`, `staff-availability`, `shift-assignment`, `shift-swap`, `roster`, `payroll-run`, `staff-compensation` | Hybrid workspace + granular REST |
| Roster engine | `backend/.../hr-roster-engine.js` | Generate assignments, coverage metrics |
| Feature flag | `hr_workspace_v1` | Required for `/hr` routes |
| Module gate | `hr-rosters` + `hrRead`/`hrWrite`/`rosterWrite`/`rosterApprove`/`rosterPublish`/`financialApprove` | `AccessRequirement` on workspace page |
| Deep links | `HrWorkspaceQuery.fromUri` | `?id=`, `?queue=`, `?search=` |
| Toolbar actions | Work queues, schedule template, HR activity | Secondary toolbar + overflow notifications submenu |
| Staff detail actions | 10 permission-gated actions wired | Assign dept/position, availability, leave, shift, swap, compensation, payroll, role, module access |
| Work queue row actions | Per-queue approve/reject/generate/publish/preview/process | Partially complete; depends on demo data |
| Localization | `app_en.arb` | HR strings largely defined |
| Backend tests | hr-workspace service/schema tests | Present |

### Known gaps to close

**UI/UX (priority — see Phase 1 below)**

- Misleading **"Manage schedule templates"** toolbar label — opens create-only form.
- Work-queue switcher is **icon-only on desktop**; queue purpose unclear without tooltips.
- **Notifications submenu** in overflow menu closes when moving pointer to child items.
- Staff directory: **truncated** next-action column; noisy department IDs in table.
- Summary notification can **overlap** table content.
- Staff detail: **maximize/resize broken** (`AppDialog`); redundant footer Close; weak overview layout; unstructured action grid; duplicate titles.
- HR activity timeline sparse — purpose needs clearer copy (optional actor/deep link).

**Feature completeness**

- **Staff onboarding** — `showHrCreateUserDialog` exists; integrate into add-staff flow with user picker (not manual `user_id`).
- **Schedule templates** — create dialog exists; no list/edit/delete or attach-to-staff bulk workflow.
- **Multi-department UX** — end-assignment dialog exists; clarify primary vs additional assignments in UI.
- **Work-item queues** — verify all queue types load demo data; ensure approve/reject/publish/preview paths refresh counts end-to-end.
- **Compensation pay types** — `PER_HOUR`, `PER_MONTH`, `PER_PROCEDURE` only; per task/review not in schema.
- **Roster ↔ OPD scheduling** — provider schedules not fully unified with HR rosters.
- **Access Admin deep-link** — optional "Open in Users/Roles" from staff detail.
- **Page decomposition** — `hr_workspace_page.dart` still monolithic; continue extraction to `presentation/widgets/`.
- **Frontend tests** — expand beyond backend coverage.
- **Feature flag docs** — document `hr_workspace_v1` + `hr-rosters` for dev/demo.

---

## Phase 1 — UI/UX Polish (do first)

Land [prompt2.md](../prompt2.md) then [prompt1.md](../prompt1.md). Summary of required changes:

### Toolbar

- Order: **Work queues → Create schedule template → HR activity**; keep Work queues inline on md+ (`maxVisibleScreenActions`).
- Rename `hrShiftTemplateAction` to **"Create schedule template"** (or add manage list + create if low effort).
- Fix `_ToolbarNotificationsSubmenu` in `app_workspace_toolbar.dart` — **click-to-open**, stable pointer path to child items.

### Work queues dialog

- Extract `hr_queue_switcher.dart` — **icon + label on md+**, icon-only on compact.
- `controller.applyQueue` must refresh table, description, loading, and empty state per queue.
- Remove footer Close; header ✕ only.

### Staff directory

- Next action: use link button or prevent "Review profile" truncation.
- Department column: name only (ID in detail/copy affordance).
- Role column: omit "Not available" subtitle when practitioner type is null.
- No floating summary over table rows.

### Staff detail dialog

- Fix `AppDialog` maximize/resize per prompt2.md.
- Single title in dialog header; staff display ID as description only.
- Reorganize overview `AppInfoTileGrid` — identity, role, placement, dates, linked user (structured sub-lines).
- Group staff actions: **Placement | Scheduling | Payroll | Access** — same handlers, better layout (`AppPermissionActionList`, `minItemWidth` ~200).
- Remove footer Close.

### HR activity

- Clarify `hrActivityDescription` as audit-style feed; remove footer Close.

**Phase 1 out of scope:** rewiring staff-action mutation logic beyond layout; full template CRUD; backend schema changes unless queues fail to load.

---

## Scope — Core Capabilities

Implement or finish the following. Status reflects codebase today.

### 1. Staff directory and profiles

**Goal:** Searchable workforce directory with professional detail dialog for every staff member.

**Status:** Directory and detail dialog exist; Phase 1 polishes columns and layout.

**Actions:**

- Primary layout: **staff directory** (default) → row opens **staff detail dialog** (`AppListTable`, `AppDialog`, `AppWorkspaceDetailPanel` content).
- Directory columns: staff number, name, position, primary department, status, next action — names over raw UUIDs; department ID only in detail.
- Search and filters: text search, position, department, practitioner type via `AppSearchBar` advanced filters.
- Detail overview: grouped `AppInfoTileGrid` (see Phase 1).
- **Add staff** / **Edit staff** via `showAppWorkspaceMutationDialog`; extend create flow with user picker or `showHrCreateUserDialog` nested sub-modal.
- Deep links: `/hr?id={staffDisplayId}` pre-selects and opens detail.

**APIs:** `GET /hr/workspace`, `GET/POST/PUT /staff-profiles`.

### 2. Roles, permissions, and module access

**Goal:** HR grants roles and surfaces module rights for OPD/IPD/clinical modules.

**Status:** Assign role, revoke role (in roles section), view module access dialogs exist in `hr_enhanced_dialogs.dart`.

**Actions:**

- Verify assign/revoke refresh detail and access summary after mutation.
- Module access summary: subscribed modules reachable (roles + entitlements).
- Coordinate Users/Roles APIs — no permission group CRUD in HR.
- Optional: **Open in Users/Roles** deep-link for advanced editing.
- Gate with `AccessRequirement` (HR write + admin permissions).

**APIs:** Users/Roles endpoints; `GET /hr/reference-data` (roles).

### 3. Positions and department assignments

**Goal:** Position/title and one or more department assignments per staff.

**Status:** Assign position, assign department, end assignment dialogs wired.

**Actions:**

- Assignments section: active + historical rows; primary vs additional clearly labeled.
- Directory shows primary department only.
- Verify end-assignment refreshes directory and detail.

**APIs:** `POST /staff-assignments`, `GET /staff-assignments?staff_profile_id=`, `PUT /staff-profiles/:id`.

### 4. Leave and availability

**Goal:** Approve leave; availability informs roster generation.

**Status:** Request leave from detail; leave queue with approve/reject; record availability dialog.

**Actions:**

- Work queue **Leave requests** — approve/reject with reason (nested confirmation).
- Summary notification count → opens work-queue dialog on leave queue.
- Refresh detail leave section and counts after approval/rejection.

**APIs:** `POST /staff-leaves`, `POST /hr/leaves/:id/approve|reject`, `POST /staff-availabilities`.

### 5. Work schedules, shift templates, and rosters

**Goal:** Templates, individual shifts, roster generate/publish.

**Status:** Create shift template dialog; assign shift/swap; roster generate/publish/preview in queue actions.

**Actions:**

- **Templates:** create (done) → add list/edit/delete + attach to staff via shift/roster flows.
- **Assign shift** — optionally from template.
- Work queues: roster drafts (generate, preview, publish), unassigned/overdue shifts (override), swap requests.
- Roster workflow: draft → generate → review → approve → publish + notify.
- Coordinate OPD provider scheduling — do not duplicate OPD encounter logic.

**APIs:** `POST /hr/rosters/:id/generate|publish`, `POST /hr/shifts/:id/override`, `POST /shift-assignments`, `POST /hr/swaps/:id/approve|reject`.

### 6. Payroll and compensation

**Goal:** Per-staff compensation and facility payroll runs.

**Status:** Compensation dialog; run payroll from detail; preview/process in payroll draft queue.

**Actions:**

- Pay types: `PER_HOUR`, `PER_MONTH`, `PER_PROCEDURE` (extend schema only if product approves per task/review).
- Multiple compensation rows with effective dates; detail **Compensation** section.
- **Preview payroll** (`GET /hr/payroll-runs/:id/preview`) before process — nested modal.
- Gate with `hrWrite` + `financialApprove`.

**APIs:** `staff_compensation` CRUD, `POST /payroll-runs`, `GET /hr/payroll-runs/:id/preview`, `POST /hr/payroll-runs/:id/process`.

### 7. Work-item queues and summary notifications

**Goal:** Pending approvals visible and actionable without leaving workspace.

**Status:** Toolbar Work queues button; notifications submenu with counts; queue panel with table.

**Actions (Phase 1 + verification):**

- Labeled queue switcher on md+; live queue switching (see Phase 1).
- Summary notifications: total staff, leave, roster drafts, unassigned shifts, payroll drafts — click opens filtered work-queue dialog.
- Row actions per queue type; approval framing (status, next action, approving role).
- Hide zero-value notifications where pattern expects.

**APIs:** `GET /hr/work-items?queue=`.

### 8. Cross-module staffing enablement

**Goal:** HR-configured staff appear correctly in clinical modules.

**Actions:**

- After role assignment, realtime/session refresh so OPD/IPD/Nursing see assignable users.
- Practitioner type and department visible to provider lists.
- Demo seed: default HR user, department users per app-write-up.
- No patient-flow API calls from HR.

### 9. Deep links, notifications, and shell integration

**Goal:** Reach HR context from home and cross-module entry points.

**Actions:**

- Verify `/hr?id=&queue=&search=` router wiring and pre-selection.
- Home **approve roster** → `/hr?queue=ROSTER_DRAFTS` when entitled.
- Realtime refresh of summary counts after remote mutations.
- Shell nav badge when pending work items exist (if supported).

### 10. Widget extraction and test coverage

**Goal:** Maintainable codebase and regression safety.

**Actions:**

- Continue extraction from `hr_workspace_page.dart` → `presentation/widgets/`: staff detail body, work queue panel, queue switcher, field groups.
- Controller tests for mutations and queue filters.
- Widget tests: staff create, leave approve, roster publish, queue switcher, toolbar submenu.
- Backend: extend hr-workspace tests for new coordination endpoints if added.

---

## UI / UX Requirements

Workforce administration workspace — **not** a patient clinical queue. Mirror Users/Roles, Subscriptions, Operations.

### Organization

- **Staff directory** (default) — browse and open detail dialog.
- **Work queues** — toolbar dialog + notification shortcuts for approvals.
- Progressive disclosure: notification counts in toolbar; advanced filters in search; complex forms in nested modals.
- Role-appropriate actions per permissions (HR manager, roster supervisor, payroll approver).

### Simplicity

- Hospital workflow language: "Assign to department", "Approve leave", "Publish roster" — not `ROSTER_DRAFTS` or `PER_HOUR`.
- One status chip + next-action per queue row and directory row.
- Staff detail action hierarchy: profile → placement → scheduling → payroll → access.

### Professional HR feel

- Calm admin aesthetic; urgency only on overdue/unassigned items.
- Copyable display IDs where useful; no patient data in HR.
- Full theme support; semantic labels on tables and dialogs.
- Dialogs resizable and maximizable on desktop (prompt2.md).

### Modal-first (mandatory)

- All mutations via `showAppWorkspaceMutationDialog`, `AppDialog`, or nested modals.
- Multi-step flows (roster preview → publish; payroll preview → process) use nested modals.
- No `/hr/staff/:id/edit` workflow routes.

---

## Architecture and Conventions

Follow `frontend/.cursor/feature_workflow.mdc`, `architecture.mdc`, `realtime_sync.mdc`.

| Rule | Requirement |
| ---- | ----------- |
| Layering | Widgets → controllers → repository → API. No API calls from widgets. |
| State | `AsyncNotifier` + `Result<T>` / `AppFailure`. |
| Permissions | `AccessGate` / `AppAccessActionGate`; module + permission constants on page. |
| Scope | Tenant, facility, department on assignments and rosters. |
| Module boundaries | No patient registry, OPD queues, IPD admissions, or patient billing in HR. |
| File size | Extract widgets; shared components in `frontend/lib/shared/`. |
| Backend | Prefer extending hr-workspace service for coordinated mutations. |

**Do not** create OPD encounters, IPD admissions, or patient billing from HR.

---

## Module Boundaries (do not violate)

| Module | Owns | HR must not duplicate |
| ------ | ---- | --------------------- |
| **HR** | Staff, assignments, leave, availability, shifts, rosters, payroll | — |
| **Users/Roles** | Auth accounts, permission groups, role definitions | Full permission matrix editing |
| **Subscriptions** | Plan modules and entitlements | Subscription CRUD |
| **OPD / IPD / Clinical** | Patient flows and encounters | Patient queues or clinical actions |
| **Billing** | Patient invoices | Patient billing (payroll only) |
| **Nursing** | Ward care on IPD admission | Nursing notes, MAR, vitals |
| **Tenant/Facility** | Org structure master data | Facility/department CRUD |

---

## Suggested Implementation Order

| Phase | Focus | Prompt / area |
| ----- | ------- | ------------- |
| **0** | `AppDialog` resize and maximize | [prompt2.md](../prompt2.md) |
| **1** | Toolbar, queues, staff detail layout, notifications submenu | [prompt1.md](../prompt1.md) |
| **2** | Onboarding integration (user picker / create-user sub-modal) | §1, §2 |
| **3** | Schedule template list/edit + attach to staff | §5 |
| **4** | Work queue E2E verification + demo seed data for all queues | §4, §5, §7 |
| **5** | Widget extraction from `hr_workspace_page.dart` | §10 |
| **6** | Multi-assignment UX polish, Access Admin deep-link | §3 |
| **7** | Compensation pay-type extension (if approved), roster ↔ OPD coordination | §5, §6 |
| **8** | Deep links, home integration, nav badges | §9 |
| **9** | Tests + quality gate | §10 |

---

## Acceptance Criteria

### Phase 1 — UI/UX

- [ ] Work queues is a labeled toolbar button on md+; queue switcher shows labels on large screens.
- [ ] Schedule-template button label matches behavior ("Create schedule template" or manage+create).
- [ ] Notifications submenu items clickable without hover-dismiss.
- [ ] Staff directory: no truncated next action; department without raw DEP- IDs; no summary overlap.
- [ ] Staff detail: full viewport maximize, grouped overview, grouped actions, no duplicate Close/title.
- [ ] HR activity description clear; footer Close removed from HR dialogs.

### Feature completeness

- [ ] HR can add, edit, and view staff profiles from `/hr` without route navigation.
- [ ] HR can assign/revoke roles and view module access for linked users.
- [ ] HR can assign departments (primary + additional) with end-assignment flow.
- [ ] HR can set position, compensation, availability, shifts, and use schedule templates.
- [ ] HR can generate, preview, and publish rosters from work queues.
- [ ] HR can preview and process payroll runs from detail or payroll queue.
- [ ] Leave and swap queues fully actionable with permissions and l10n.
- [ ] Clinical staff assignable in OPD/IPD via user/role system per flow §5 / §13.
- [ ] No patient-flow API calls from HR; all actions modal-first.
- [ ] `hr_workspace_v1` + `hr-rosters` documented for dev/demo.

### Quality

- [ ] `flutter analyze`, HR tests, targeted backend tests pass.
- [ ] Manual QA: `.\tool\run_web_5201.ps1` → `/hr` → toolbar → all queue tabs → notifications → staff detail resize/maximize → assign role → roster publish → payroll preview.

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/` when touching API or schema:

```sh
npm test -- --testPathPattern="hr-workspace|staff-profile|roster|payroll"
```

Manual QA (web):

```sh
cd frontend
.\tool\run_web_5201.ps1
```

Navigate to `/hr` → work queues (switch all tabs) → open staff → resize/maximize detail → assign department and role → create schedule template → approve roster draft → preview payroll.

---

## Key File References

```
frontend/lib/features/hr/
  presentation/pages/hr_workspace_page.dart
  presentation/controllers/hr_workspace_controller.dart
  presentation/widgets/hr_enhanced_dialogs.dart
  presentation/widgets/                    — hr_queue_switcher, extractions
  domain/entities/hr_entities.dart
  data/repositories/hr_repository_impl.dart
  data/dtos/hr_dtos.dart

frontend/lib/shared/
  components/app_dialog.dart               — prompt2.md
  layout/app_workspace_toolbar.dart        — notifications submenu
  actions/app_action_panel.dart
  components/app_info_tile.dart

backend/src/modules/hr-workspace/
  routes/hr-workspace.routes.js
  services/hr-workspace.service.js
  services/hr-roster-engine.js

Related prompts:
  prompt1.md                                 — HR UI/UX polish (focused)
  prompt2.md                                 — AppDialog sizing/maximize
  prompts/04-access-admin-module-prompt.md
  prompts/12-opd-module-prompt.md
  prompts/19-ipd-module-prompt.md
  prompts/09-billing-module-prompt.md

Standards:
  .cursor/app-write-up.mdc
  .cursor/flows/opd-flow.mdc, ipd-flow.mdc, nursing-flow.mdc
  frontend/.cursor/ui-workspace.mdc, design-system.mdc, realtime_sync.mdc
```

---

## Deliverable

A production-ready HR workspace — frontend and backend as needed — that completes Phase 1 UI polish, closes remaining feature gaps, respects module and flow boundaries, and delivers modal-first workforce administration enabling hospital clinical and operational modules.
