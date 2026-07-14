# Integrations Module — Implementation Prompt

## Objective

Complete the **Integrations Module** for HOSSPI HMS: API keys, external integrations, integration logs, webhooks, interoperability configuration (FHIR/HL7/DICOM where applicable), and external system status — enabling hospital systems to connect without embedding integration logic in OPD/IPD clinical paths.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Integrations row
2. Clinical modules — PACS in [prompts/17-radiology-module-prompt.md](./17-radiology-module-prompt.md); FHIR patient sync may reference patient registry

**Central rule:** integrations are **admin/technical** configuration. OPD and IPD flows consume outcomes (e.g., imaging from PACS, lab results from external LIS) via backend services — not via ad-hoc UI in clinical workspaces.

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

### OPD / IPD (indirect)

| Concept | Integrations responsibility |
| ------- | --------------------------- |
| PACS / DICOM | Radiology `pacs-sync` — configured here, executed in radiology workflow |
| External lab | Results may arrive via integration — surface on lab orders without OPD stage hacks |
| Webhooks | Post domain events (admission, discharge) to external systems |
| API keys | Scoped permissions for third-party read/write — never bypass RBAC |

### App write-up

- Integration logs with replay for failed deliveries.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/integrations/` | Workspace page, controller, repository |
| Backend | `integration`, `integration-log`, `api-key`, `webhook-subscription`, `interop` | |
| APIs | Integrations CRUD + test/sync; API keys; webhooks; `POST /integration-logs/:id/replay`; `/interop` routes | |
| Interop UI | **Hardcoded** capabilities in repository — no live `/interop` calls | |

### Known gaps

- No backend `integrations-workspace` aggregator
- Interop panel not wired to backend
- Webhook secret rotation / retry UX minimal
- Log replay limited UI surfacing
- Link radiology PACS config to integration records

---

## Scope — Core Capabilities

1. **Integrations registry** — create, test connection, sync now, disable.
2. **API keys** — issue, revoke, permission scopes.
3. **Webhooks** — subscriptions, delivery logs.
4. **Integration logs** — filter, replay failed events.
5. **Interop** — wire FHIR/HL7/DICOM status from `/interop` APIs (replace hardcoded list).

---

## UI / UX Requirements

This is an **integrations admin** surface — management tables/cards with status indicators and log viewers, **not** a patient worklist.

- **Layout:** `AppWorkspace` shell with sections for Integrations, API Keys, Webhooks, Integration Logs, and Interop. Use `AppListTable` (or status cards) with `app_search_bar` and filters; selecting a record opens a detail panel.
- **Status-first display:** each integration/webhook/external system shows a clear status indicator (connected/degraded/disabled/error) and last-sync/last-delivery time; surface `/interop` FHIR/HL7/DICOM status live (replace the hardcoded list).
- **Config & lifecycle actions in modals:** create/edit/test-connection/sync-now/disable for integrations, issue/revoke API keys with permission scopes, and create/rotate webhook subscriptions all use `AppDialog` / `app_workspace_mutation_dialog`; use nested modals for sub-steps (e.g., scope selection, secret rotation confirmation). Surface secrets/keys once with `app_copyable_identifier`.
- **Integration logs:** filterable log viewer with delivery/replay detail; replay failed events from a confirmation modal.
- Theming (light/dark/system), full localization via `app_en.arb`, and responsive layout across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Peer with admin management/configuration console patterns (status tables, log viewers) for consistency — not clinical worklists.

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

- [ ] Admins can manage API keys and webhooks with audit trail.
- [ ] Integration test/sync actions show clear success/failure.
- [ ] Clinical modules unaffected when integration disabled — graceful degradation.
- [ ] Interop capabilities loaded from backend when available.

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
frontend/lib/features/integrations/
backend/src/modules/integration/, api-key/, webhook-subscription/, interop/

Related prompts: prompts/17-radiology-module-prompt.md, prompts/03-tenant-facility-module-prompt.md
```
