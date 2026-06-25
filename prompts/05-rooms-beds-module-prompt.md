# Rooms, Wards, and Beds Module — Implementation Prompt

## Objective

Complete the **Rooms, Wards, and Beds Module** for HOSSPI HMS so facility admins and bed managers can manage physical care spaces end-to-end: wards, rooms, beds, bed status, assignments, occupancy visibility, and **IPD bed operations** (assign, release, transfer request) — consuming organizational structure from tenant/facility setup.

**Source of truth (read in this order):**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Rooms/wards/beds vs Tenant/Facility settings vs IPD
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 bed management, §14.2 bed board, statuses, assign/transfer/release
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — indirect; bed ops are post-admit only

**Central rule:** master ward/room/bed structure is owned by **facility catalog** ([prompts/03-tenant-facility-module-prompt.md](./03-tenant-facility-module-prompt.md)). This module focuses on **operational bed board**: status, assignment, and IPD orchestration actions.

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


## Flow Integration Requirements

### IPD flow (`../.cursor/flows/ipd-flow.mdc`)

| IPD concept | Rooms/beds module responsibility |
| ----------- | -------------------------------- |
| §3 Bed statuses | `Available`, `Reserved`, `Occupied`, `Cleaning`, `Maintenance`, `Blocked` |
| Steps 5–6 | Bed request and allocation UI; waitlist when unavailable |
| §9 Transfers | Request transfer; complete with `update-transfer` when API wired |
| Step 18 | Release bed for cleaning after discharge |
| §14.2 Bed board | Live board: ward, room, bed, status, patient, next action |
| §13 Bed manager role | Reserve, allocate, transfer, release |

### OPD flow (`../.cursor/flows/opd-flow.mdc`)

| OPD concept | Rooms/beds responsibility |
| ----------- | ------------------------- |
| `ADMITTED` | Bed assignment happens in IPD/rooms-beds — not in OPD workspace |
| No OPD mutations | Bed module does not change OPD stages |

### Cross-module

| Module | Integration |
| ------ | ----------- |
| Housekeeping | Bed `Cleaning` → turnover tasks ([prompts/27-housekeeping-module-prompt.md](./27-housekeeping-module-prompt.md)) |
| Operations | `Maintenance`/`Blocked` beds link to maintenance requests ([prompts/26-operations-module-prompt.md](./26-operations-module-prompt.md)) |
| IPD workspace | Patient board + bed board may share data — avoid duplicate bed CRUD |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/rooms_beds/` | Workspace page, controller, repository |
| Catalog CRUD | Via `tenant_facility_repository` | Ward/room/bed save |
| IPD bed ops | `POST /ipd-flows/:id/assign-bed`, `release-bed`, `request-transfer` | Partial wiring |
| Backend | `ward`, `room`, `bed`, `bed-assignment` modules | Master data + assignments |

### Known gaps

- `update-transfer` (approve/complete) not in rooms_beds repository
- Duplicated catalog editing with tenant_facility setup
- No unified live occupancy board with IPD patient board
- Bed suitability rules (gender, isolation, equipment) not enforced in UI
- Deep links `/rooms-beds?ward=` not parsed in router

---

## Scope — Core Capabilities

1. **Bed board** — filter by ward, status; show current patient when occupied/reserved.
2. **Assign / release** — wire IPD bed actions with blocking reasons on failure.
3. **Transfer lifecycle** — request, approve, complete, cancel per ipd-flow §9.
4. **Catalog maintenance** — ward/room/bed CRUD or deep-link to tenant facility setup.
5. **Status coordination** — cleaning/maintenance states with Housekeeping and Operations.

---

## UI / UX Requirements

This is a **space-management workspace**, not a patient queue. Rows/tiles are physical beds, rooms, and wards; the current patient is shown only as context on an occupied/reserved space.

- **Layout:** `AppWorkspace` presenting a bed board grouped by ward/room, with an `AppListTable` tabular alternative. Each space shows its status badge and, when occupied/reserved, the current patient; selecting a space opens its detail panel.
- **Summary cards:** show occupancy/status counts over the board — Available, Reserved, Occupied, Cleaning, Maintenance, Blocked (per ipd-flow §3). Cards filter the board in place; they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Status visibility:** render bed status via `AppStatusText` badges; link an occupied bed to its IPD admission detail. Use hospital language, never raw enums or UUIDs.
- **Modal-first / nested-modal actions:** assign, release, request/approve/complete transfer, update status, and ward/room/bed catalog edits run via `AppWorkspaceMutationDialog` / nested modals (e.g. patient selection nested inside assign; blocking-reason surfaced on failure). Deep-link ward pre-selection (`/rooms-beds?ward=`) is allowed; actions do not navigate to new routes.
- Full theming (light/dark/system), all strings localized in `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match peer workspaces — the IPD bed board, the Tenant/Facility ward/bed catalog, and other operational management workspaces — for consistency.

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


## Acceptance Criteria

- [ ] Bed managers can view board and assign/release beds via ipd-flow APIs.
- [ ] Bed statuses align with ipd-flow §3 recommendations.
- [ ] Transfers complete end-to-end when backend supports all steps.
- [ ] No duplicate bed master data definitions vs tenant_facility.
- [ ] Links to IPD admission detail from occupied beds.

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
frontend/lib/features/rooms_beds/
frontend/lib/features/tenant_facility/
backend/src/modules/bed/, ward/, room/, ipd-flow/

Related prompts: prompts/19-ipd-module-prompt.md, prompts/03-tenant-facility-module-prompt.md, prompts/27-housekeeping-module-prompt.md
```
