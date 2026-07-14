# Biomedical Module — Implementation Prompt

## Objective

Complete the **Biomedical Engineering Module** for HOSSPI HMS so biomedical technicians and managers can run **clinical equipment lifecycle** end-to-end: equipment registry, categories, maintenance plans, work orders, calibration, safety testing, downtime, incidents, recalls, spare parts, service providers, warranties, utilization, and disposal/transfer — supporting safe clinical operations in OPD, IPD, ICU, and Theater.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Biomedical vs Operations vs Theater vs IPD boundaries
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 bed equipment needs, §6 bed suitability, §14 bed board equipment constraints
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 no clinical actions for unrelated roles; facility issues route to Operations, **clinical device faults** to Biomedical

**Module boundary:** Biomedical owns **clinical/medical equipment** lifecycle. Operations owns non-clinical facility maintenance (HVAC, plumbing, general building). Equipment downtime may affect bed assignability and theater/ICU readiness — surface status to IPD/theater when linked to ward/bed/room.

Deliver an **audit-ready equipment workbench**: fault-to-work-order pipeline, PM schedules, calibration due dates, and downtime visibility.

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

Biomedical does not own patient encounters. Integration is **operational**:

| Flow reference | Biomedical responsibility |
| -------------- | ------------------------- |
| ipd-flow §3 bed suitability | Equipment requirements (ventilator, isolation) — bed assign fails or warns when required device down |
| ipd-flow §14.2 bed board | Show equipment-linked downtime on bed/room when API provides |
| ICU / Theater | Critical devices (monitors, ventilators) — work orders prioritized; link equipment registry to location |
| Operations handoff | Non-clinical issues converted from Operations — clinical equipment faults stay in Biomedical |
| opd-flow §5 | Biomedical staff do not perform OPD clinical actions |

---

## Current State (read before changing code)

### Already in place

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend scaffold | `frontend/lib/features/biomedical/` | Workbench, fault reports, work-order actions |
| Biomedical workspace | `backend/src/modules/biomedical-workspace/` | `GET /biomedical`, lookups, `POST /biomedical/fault-reports` |
| Equipment modules | `equipment-work-order`, `equipment-registry`, `equipment-maintenance-plan`, calibration, downtime, spare-parts, etc. | Granular legacy CRUD |
| Feature flag | `biomedical_workspace_v1` | Required for workspace |
| Operations cross-link | Operations can convert to biomedical work order | See prompts/26-operations-module-prompt.md |

### Known gaps to close

- **Workspace mutations thin** — most CRUD via legacy equipment routes; align repository with workspace API growth.
- **IPD bed equipment constraints** — not wired on bed assign UI.
- **Location linkage** — ward/room/bed/ICU/theater on equipment registry.
- **PM/calibration due queues** — summary cards for overdue PM/calibration.
- **Feature flag documentation** — enablement for dev/demo.
- **Frontend tests** — service/repo tests exist; expand UI tests.
- **Deep links** — `/biomedical?id=` query params.

---

## Scope — Core Capabilities

### 1. Equipment registry and categories

- Searchable registry with location, status, warranty, service provider.

### 2. Fault reports and work orders

- Report fault from workspace; create/start/complete work orders.
- Return to service with safety sign-off.

### 3. Maintenance plans and calibration

- Scheduled PM; calibration and safety testing due dates.
- Overdue queues and notifications.

### 4. Downtime and incidents

- Record downtime; link to beds/rooms/theater when clinical impact.
- Incident and recall tracking.

### 5. Cross-module integration

- Operations → Biomedical conversion for clinical devices.
- IPD/theater bed pickers respect equipment-down flags when backend supports.

---

## UI / UX Requirements

This is an **equipment lifecycle workbench** — equipment registry, maintenance plans, work orders, calibration, and incidents — not a patient clinical queue. Mirror the **Operations** maintenance workspace (`prompts/26-operations-module-prompt.md`), its closest peer, for consistency.

- **Layout:** `AppWorkspace` shell with `AppWorkspaceSummaryGrid` cards, `AppSearchBar`, and `AppListTable` for the equipment registry and work-order/fault lists; selection opens `AppWorkspaceDetailPanel` via `AppWorkspaceSplitContent`.
- **Summary cards filter asset/work-order lists by status** (open faults, work orders in progress, overdue PM, calibration due, downtime, incidents) — they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Work-order framing:** on the fault-to-work-order pipeline, show each work order's current state plus the **next required action** (assign, start, complete, return-to-service sign-off) and the **assigned technician** on list rows; the registry view is asset reference, not an action queue.
- **Modal-first / nested-modal actions:** report fault, create/assign/start/complete work orders, record calibration/safety tests, and log downtime and incidents run in dialogs or bottom sheets (`AppActionPanel` + `showAppWorkspaceMutationDialog`) — never separate navigation routes; use nested modals for parts/checklist sub-steps.
- Use display IDs and equipment/location names — no raw UUIDs or enum codes; this is equipment management, not patient care.
- Full theme support (light/dark/system); all strings localized via `app_en.arb`; responsive on Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.

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

- Biomedical owns clinical equipment — not housekeeping cleaning, not general plumbing/HVAC (Operations).
- Do not mutate OPD/IPD patient stages.
- Do not own theater surgical documentation — only equipment used in theater.

---

## Acceptance Criteria

- [ ] Equipment registry and work-order lifecycle usable from workspace.
- [ ] Fault report → work order → return-to-service flow complete.
- [ ] PM/calibration due visibility for managers.
- [ ] Clear boundary vs Operations module.
- [ ] Optional IPD bed equipment constraint when API available.
- [ ] Feature flag and permissions enforced; tests pass.

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
frontend/lib/features/biomedical/
backend/src/modules/biomedical-workspace/
backend/src/modules/equipment-work-order/, equipment-registry/

Related prompts: prompts/26-operations-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/20-icu-module-prompt.md, prompts/21-theater-module-prompt.md
```
