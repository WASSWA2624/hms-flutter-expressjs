# Reports, Dashboards, and Audit Module — Implementation Prompt

## Objective

Complete **Reports, Dashboards, and Audit** for HOSSPI HMS: role-based reports, report definitions and runs, scheduled reports, exports, audit logs, PHI access logs, data processing logs, and compliance evidence review — **read-only** visibility into OPD/IPD and all modules without replacing module workflows.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Reports, dashboards, and audit row; Access Control Expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — audit of OPD stage transitions via backend audit layer
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — traceability §16; discharge and billing audit trails

**Central rule:** reports and audit **read from** modules; they must not mutate OPD/IPD encounters, orders, or billing.

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

### OPD / IPD

| Concept | Reports/audit responsibility |
| ------- | ---------------------------- |
| Operational reports | OPD visit volumes, wait times, disposition breakdowns |
| Inpatient reports | Admission, LOS, bed occupancy, discharge metrics |
| Audit logs | Who changed OPD stage, IPD bed assignment, discharge finalize |
| PHI access logs | Patient chart access review for compliance |
| Dashboard overlap | [prompts/07-home-dashboard-module-prompt.md](./07-home-dashboard-module-prompt.md) for landing KPIs; this module for deep reports |

### App write-up

- Scheduled reports and exports for administrators.
- Compliance evidence and activity review.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/reports/` | Workspace page, controller, repository |
| Backend | `reports-workspace`, `report-definition`, `report-run`, `report-schedule`, `audit-log`, `phi-access-log`, `data-processing-log` | |
| APIs | `GET /reports-workspace`; `POST /report-definitions/:id/run`; download report runs; compliance log lists | |
| Home | `review_audit` quick action → reports route | |
| Feature flag | `reports_workspace_v1` | |

### Known gaps

- `/reports-workspace/lookups` unused
- Download disabled when backend sets `download_available: false`
- Compliance logs read-only lists without drill-down workspace
- No embedded OPD/IPD-specific report templates in UI beyond backend definitions
- Frontend tests limited

---

## Scope — Core Capabilities

1. **Report catalog** — definitions by category; run with parameters.
2. **Report runs** — status, download/preview when available.
3. **Schedules** — CRUD scheduled reports.
4. **Audit logs** — filter by user, action, resource, date; link to entity display IDs.
5. **Compliance logs** — PHI access and data processing review for admins.

---

## UI / UX Requirements

This is a **reports, dashboards, and audit** surface — catalogs, run history, and filterable log views, **not** a patient queue.

- **Layout:** `AppWorkspace` shell with tabbed/segmented sections for Report Catalog, Report Runs, Schedules, Audit Logs, and Compliance (PHI access / data processing). Each section uses `AppListTable` with `app_search_bar` and filters; selecting a row opens a detail panel.
- **Report catalog:** definitions grouped by category; running a report opens a parameter modal (`AppDialog` / `app_workspace_mutation_dialog`), then surfaces the resulting run in run history.
- **Report runs:** status (queued/running/ready/failed) with preview/download when `download_available` is true; disable download cleanly when the backend or platform cannot serve it.
- **Schedules:** create/edit scheduled reports via modals (nested modals for parameter + recipient sub-steps).
- **Audit & compliance logs:** read-only filterable views (user, action, resource, date range) linking to entity display IDs; render as dense tables, not actionable worklist rows.
- **Dashboards:** role/action-based KPI panels (this module owns deep reports; landing KPIs belong to [prompts/07-home-dashboard-module-prompt.md](./07-home-dashboard-module-prompt.md)).
- **Read-only contract:** expose no write/mutation actions on clinical or financial entities — only run, schedule, export, and view.
- Theming (light/dark/system), full localization via `app_en.arb`, and responsive layout across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Peer with report-catalog, run-history, and audit-log review patterns for consistency — not clinical worklists.

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

- [ ] Authorized users can run and download reports per permissions.
- [ ] Audit logs searchable for OPD/IPD actions (via backend audit entries).
- [ ] Reports module does not expose write APIs for clinical/financial mutations.
- [ ] Export/download respects platform capabilities.

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
frontend/lib/features/reports/
backend/src/modules/reports-workspace/, audit-log/, phi-access-log/

Related prompts: prompts/07-home-dashboard-module-prompt.md, prompts/12-opd-module-prompt.md, prompts/19-ipd-module-prompt.md
```
