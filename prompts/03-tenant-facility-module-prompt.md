# Tenant and Facility Settings Module — Implementation Prompt

## Objective

Complete **Tenant and Facility Settings** for HOSSPI HMS so platform, tenant, and facility admins can configure the hospital organization end-to-end: tenant profile, facilities, branches, departments, units, contacts, addresses, and the **ward/room/bed catalog** that downstream clinical modules consume.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Tenant settings, Facility settings, Rooms/wards/beds boundaries
2. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §3 ward/bed classes used at admission (consume config, do not redefine)
3. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — service units and provider context consume facility structure

**Central rule:** organizational structure is defined **once** here. OPD, IPD, Nursing, and Rooms/Beds modules **consume** ward/bed/department IDs — they must not maintain parallel facility masters.

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

### IPD / OPD (indirect)

| Flow concept | Tenant/facility responsibility |
| ------------ | ---------------------------- |
| Ward/bed classes | Configure wards, rooms, beds with types (ICU, isolation, etc.) |
| Departments/units | Service points for OPD routing and IPD consultant assignment |
| Facility scope | All CRUD respects tenant/facility scope from session |

### App write-up (`../.cursor/app-write-up.mdc`)

| Module row | This module owns |
| ---------- | ---------------- |
| Tenant settings | Tenant profile, subscription relationship, enabled modules, tenant admins |
| Facility settings | Facility identity, branches, departments, units, wards, beds, defaults |
| Rooms, wards, beds | Physical structure — operational bed board is [prompts/05-rooms-beds-module-prompt.md](./05-rooms-beds-module-prompt.md) |

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/tenant_facility/` | `tenant_facility_setup_page.dart`, repository, catalog panels |
| Backend | `tenant`, `facility`, `branch`, `department`, `unit`, `ward`, `room`, `bed`, `contact`, `address` | Granular CRUD |
| Auth bootstrap | Registration may seed default tenant/facility | See [prompts/01-auth-module-prompt.md](./01-auth-module-prompt.md) |
| Settings hub | Routes to tenant_facility for catalog sections | [prompts/06-settings-profile-module-prompt.md](./06-settings-profile-module-prompt.md) |

### Known gaps

- No backend `tenant-facility-workspace` aggregator — client composes many calls
- Users/roles admin not in this feature ([prompts/04-access-admin-module-prompt.md](./04-access-admin-module-prompt.md))
- Large monolithic setup page — split by entity or wizard steps
- Facility clinical catalog (diagnoses, procedures) partially in shared clinical catalog UI
- Validation gaps on optional branch/department fields

---

## Scope — Core Capabilities

1. **Tenant profile** — name, contacts, subscription visibility (read link to subscriptions).
2. **Facility identity** — logo, address, contacts, branches.
3. **Organizational tree** — departments, units, service points.
4. **Care spaces** — wards, rooms, beds with types and active flags.
5. **Guided setup** — main setup flow steps 1–4 from app-write-up Main Setup Flow.

---

## UI / UX Requirements

This is an **organizational configuration workspace**, not a patient worklist. Rows are tenants, facilities, branches, departments, units, wards, rooms, and beds.

- **Layout:** `AppWorkspace` with section navigation across Tenant Identity, Facilities & Branches, Departments & Units, and the Ward/Room/Bed catalog. Present the hierarchy as structured `AppListTable` management lists or a parent→child tree; selecting a row opens its detail panel.
- **Summary cards:** show structural counts/status filters over the catalog — e.g. facilities, departments, wards, beds, active vs inactive. Cards filter the lists in place; they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Status visibility:** surface entity type, active flag, and parent context (facility → ward → room → bed) as columns and `AppStatusText` badges. Use hospital language, never raw enums or UUIDs.
- **Modal-first / nested-modal editors:** create/edit tenant, facility, branch, department, unit, ward, room, and bed via `AppWorkspaceMutationDialog` / shared form components (`AppFormShell`, `AppFormSection`, `AppTextField`, `AppSwitchField`). Use nested modals for child entities (e.g. add a bed from within a ward editor). No route navigation for editors.
- Full theming (light/dark/system), all strings localized in `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match peer admin/management workspaces — Subscriptions, Users/Roles/Permissions, and the Rooms/Wards/Beds operational board — for consistency.

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

- [ ] Admins can configure tenant and facility hierarchy end-to-end.
- [ ] Wards/beds created here appear in IPD and rooms_beds modules.
- [ ] No duplicate structure definitions in clinical modules.
- [ ] Tenant/facility scope enforced on all mutations.

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
frontend/lib/features/tenant_facility/
backend/src/modules/tenant/, facility/, ward/, room/, bed/

Related prompts: prompts/05-rooms-beds-module-prompt.md, prompts/02-subscriptions-module-prompt.md, prompts/04-access-admin-module-prompt.md
```
