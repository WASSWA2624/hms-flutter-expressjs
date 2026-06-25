# Home and Dashboard Module — Implementation Prompt

## Objective

Complete the **Home Dashboard and App Shell Entry** for HOSSPI HMS: role-based landing experience, workload summaries, quick actions into OPD/IPD and other modules, notification badges, and integration with backend dashboard workspace — the first screen staff see after login.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — App identity and shell; Reports/dashboards row (widgets may embed here)
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — queue entry points for OPD roles
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — admission/bed queue entry for IPD roles

**Central rule:** Home is the **app shell entry**. It may navigate to module routes (`/opd`, `/ipd`, etc.) via quick actions and show workload summaries — it does **not** duplicate module worklists or host clinical workflow forms. Any drill-down from dashboard widgets must use **modals** or deep-link pre-selection on the target workspace, not intermediate workflow routes. Summary counts should match backend queue metrics when the dashboard API provides them.

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

### OPD flow

| Concept | Home responsibility |
| ------- | ------------------- |
| Role cards | Reception, nurse, doctor quick links to `/opd` with optional scope |
| Queue previews | Show OPD stage counts when `dashboard-workspace` provides KPIs |
| Workload badges | Nav badge patterns consistent with `opdWorkspaceController.workloadCount` |

### IPD flow

| Concept | Home responsibility |
| ------- | ------------------- |
| Bed/admission previews | IPD pending bed, discharge planned counts when API embeds |
| Quick actions | Link to `/ipd`, `/nursing`, `/discharge` per role profile |

### App shell

- App bar, user menu, notification badge entry to [prompts/29-communications-module-prompt.md](./29-communications-module-prompt.md).
- HOSSPI HMS branding per app identity row.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/home/` | `home_page.dart`, `home_repository_impl`, dashboard profiles |
| Backend | `dashboard-workspace`, `dashboard-widget`, `kpi-snapshot` | |
| API | `GET /dashboard-workspace/workspace` | Lookups endpoint unused |
| Fallback | Static role-based cards when no tenant or `AppRole.other` | |

### Known gaps

- Heavy reliance on fallback stub data
- `/dashboard-workspace/lookups` not called
- Queue preview/alerts empty in fallback mode
- Feature flag `dashboard_workspace_v1`
- Home page very large — extract role profile widgets

---

## Scope — Core Capabilities

1. **Role-based dashboard** — different quick actions per doctor, nurse, admin, etc.
2. **Live KPIs** — OPD waiting counts, IPD bed pressure, critical alerts when backend supplies.
3. **Quick navigation** — one-click to highest-workload module for role.
4. **App shell polish** — consistent with `frontend/.cursor/layouts.mdc` and navigation rules.
5. **Realtime** — refresh counts on domain events where feasible.

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


## Acceptance Criteria

- [ ] After login, user lands on meaningful role-specific home.
- [ ] OPD/IPD entry points visible for clinical roles with correct permissions.
- [ ] Dashboard uses backend workspace when flag enabled; graceful fallback otherwise.
- [ ] Notification badge links to communications module.

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
frontend/lib/features/home/
backend/src/modules/dashboard-workspace/
frontend/lib/app/router/app_router.dart

Related prompts: prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md, prompts/29-communications-module-prompt.md, prompts/30-reports-audit-module-prompt.md
```
