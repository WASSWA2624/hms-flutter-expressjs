# Subscription Management Module — Implementation Prompt

## Objective

Complete **Subscription Management** for HOSSPI HMS so tenant admins and platform operators can manage commercial entitlements end-to-end: subscription plans, active subscriptions, module subscriptions, licenses, invoices, renewal state, and plan limits — controlling which hospital modules (including OPD and IPD) are enabled.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Subscription management row; demo seed subscription data
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — OPD module gated by `opd-flow` entitlement
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — IPD gated by `inpatient-bed-management` / related entitlements

**Central rule:** module entitlements drive route visibility and backend `module-entitlement` middleware. Subscription changes should prompt session refresh or realtime entitlement updates.

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

| Concept | Subscriptions responsibility |
| ------- | -------------------------- |
| Module gates | `module-subscription` activates OPD, IPD, ICU, etc. |
| Plan limits | Enforce user/bed/module limits per plan — surface in admin UI |
| Demo seed | Default plan + module subscriptions for safe demos (app-write-up) |

### App write-up

- Subscription invoices, renewal, license state visibility for tenant admins.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Frontend | `frontend/lib/features/subscriptions/` | Workspace page, controller, repository |
| Backend | `subscriptions-workspace`, `subscription-plan`, `subscription`, `module-subscription`, `license`, `subscription-invoice` | |
| APIs | `GET /subscriptions-workspace/workspace`; plan/subscription CRUD; renew/upgrade/downgrade; module activate/deactivate; invoice collect/retry | |
| Feature flag | Workspace may be gated | |

### Known gaps

- `reference-data` and `resolve-legacy` unused in frontend
- No payment-provider checkout UI for invoice collect
- Entitlement changes not realtime on other open workspaces
- Cross-tenant super-admin UX limited
- Link from tenant setup to subscription status could be stronger

---

## Scope — Core Capabilities

1. **Plans and tiers** — CRUD subscription plans; feature/module matrix.
2. **Active subscription** — renew, upgrade, downgrade with confirmation.
3. **Module subscriptions** — enable/disable clinical modules per tenant.
4. **Licenses** — view license state and limits.
5. **Invoices** — list subscription invoices; collect/retry when API supports.

---

## UI / UX Requirements

This is a **commercial administration workspace**, not a patient worklist. Rows are plans, subscriptions, modules, licenses, and invoices.

- **Layout:** `AppWorkspace` with a section switcher across Plans, Active Subscription, Module Subscriptions, Licenses, and Invoices. Each section is an `AppListTable` management list with a detail panel and modal actions.
- **Summary cards:** show commercial counts/status filters over the management list — e.g. active vs expiring subscriptions, enabled modules, overdue invoices. Cards filter the list in place; they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Status visibility:** render plan tier, module on/off, license limits/usage, and invoice/renewal state as columns and `AppStatusText` badges. Use hospital/commercial language, never raw enums or UUIDs.
- **Modal-first / nested-modal actions:** renew, upgrade, downgrade, activate/deactivate module, and collect/retry invoice run via `AppWorkspaceMutationDialog` / nested modals (e.g. plan picker nested inside upgrade, confirmation on downgrade with limit impact). No route navigation for actions.
- Full theming (light/dark/system), all strings localized in `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match peer admin/management workspaces — Tenant/Facility Settings and Users/Roles/Permissions — for consistency.

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

- [ ] Tenant admin can view and manage subscription and module entitlements.
- [ ] Disabling OPD/IPD module hides routes and backend returns 403/404 appropriately.
- [ ] Demo seed subscription documented and testable.
- [ ] No raw UUIDs; permissions enforced.

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
frontend/lib/features/subscriptions/
backend/src/modules/subscriptions-workspace/

Related prompts: prompts/03-tenant-facility-module-prompt.md, prompts/04-access-admin-module-prompt.md
```
