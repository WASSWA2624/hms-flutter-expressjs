# Users, Roles, and Permissions Module — Implementation Prompt

## Objective

Complete **Users, Roles, and Permissions** administration for HOSSPI HMS so tenant and facility admins can manage staff access end-to-end: user accounts, role assignment, permission groups, action permissions, activation, demo accounts, and access scope — enabling correct RBAC/ABAC across all clinical and operational modules.

**Source of truth:**

1. [app-write-up.mdc](../.cursor/app-write-up.mdc) — Users/roles row, Access Control Expectations
2. [flows/opd-flow.mdc](../.cursor/flows/opd-flow.mdc) — §5 role/action rules (admin configures who may act)
3. [flows/ipd-flow.mdc](../.cursor/flows/ipd-flow.mdc) — §13 role actions by admission desk, bed manager, nurse, doctor, etc.

**Central rule:** backend authorization is the source of truth; frontend mirrors permissions in `AccessGate` / `AppAccessActionGate`. This module administers assignments — individual modules only **request** permissions.

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

### OPD / IPD flows

| Concept | Access admin responsibility |
| ------- | --------------------------- |
| Role matrices | Ensure roles exist for reception, nurse, doctor, billing, lab, radiology, pharmacy per flow §5 / §13 |
| Module entitlements | Tie subscription module flags to role visibility ([prompts/02-subscriptions-module-prompt.md](./02-subscriptions-module-prompt.md)) |
| Multi-role users | Support users with more than one role per app-write-up |
| Scope | Tenant, facility, department, ward scope on assignments where applicable |

### App write-up — Access Control Expectations

- Every screen, menu, button, API call must respect role, permission, tenant scope, facility scope, and module entitlement.
- Frontend hiding is not enough — document that backend routes enforce auth.

---

## Current State (read before changing code)

| Area | Location / API | Notes |
|------|----------------|-------|
| Backend | `user`, `role`, `permission`, `role-assignment`, `module-entitlement` patterns | CRUD across modules |
| Frontend | **No dedicated feature folder** — settings workspace maps routes; UI largely unimplemented |
| Home | `manage_users_roles` action → settings/tenant routes | Navigation stub |
| HR | Staff profiles link to users | [prompts/24-hr-module-prompt.md](./24-hr-module-prompt.md) |
| Permissions client | `frontend/lib/core/permissions/` | Consumes session permissions |

### Known gaps

- No users/roles workspace UI (settings references unimplemented routes)
- No role assignment UI from HR staff profiles
- Demo account seeding documented in app-write-up but admin UI to view/reset missing
- Break-glass / elevated access not surfaced in admin UI if backend supports
- Audit of permission changes not in admin workspace

---

## Scope — Core Capabilities

1. **User directory** — search staff users; activate/deactivate; link to HR profile when exists.
2. **Role management** — assign/revoke roles; show effective permissions preview.
3. **Permission groups** — view action permissions; avoid editing system-critical roles without safeguards.
4. **Module entitlements** — show which modules user may access per subscription.
5. **Demo accounts** — list seeded demo users; reset passwords in non-production.

---

## UI / UX Requirements

This is an **access administration workspace**, not a patient worklist. Rows are users, roles, and permission groups.

- **Layout:** `AppWorkspace` with sections for Users, Roles, and Permission Groups. Each is an `AppListTable` management list with a detail panel — the user panel shows assigned roles and effective permissions; the role panel shows its permission matrix.
- **Summary cards:** show counts/status filters over the lists — e.g. active vs deactivated users, role counts, demo accounts, users with no role. Cards filter the list in place; they must not open separate routes. Hide zero-value cards where the pattern expects it.
- **Status visibility:** surface account state, role assignments, scope (tenant/facility/department), and module entitlement as columns and `AppStatusText` badges. Use staff-facing language, never raw enums or UUIDs.
- **Modal-first / nested-modal actions:** create/edit user, activate/deactivate, assign/revoke roles, and edit permission groups run via `AppWorkspaceMutationDialog` / nested modals. Render the permission matrix as grouped toggles inside the modal or detail panel. Gate every action with `AccessGate` / `AppAccessActionGate`. No route navigation for actions.
- Full theming (light/dark/system), all strings localized in `app_en.arb`, responsive across Android, iOS, web, Windows, macOS, Linux.
- Stable, error-free widgets; no runtime or compilation regressions.
- Match peer admin/management workspaces — Subscriptions and Tenant/Facility Settings — for consistency.

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

- [ ] Admins can assign roles that unlock OPD/IPD actions per flow role tables.
- [ ] UI changes reflect in module menus and action gates after session refresh.
- [ ] Backend rejects unauthorized actions even if UI regresses.
- [ ] Tenant/facility scope enforced on user administration.

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
backend/src/modules/user/, role/, permission/
frontend/lib/core/permissions/
frontend/lib/features/settings/

Related prompts: prompts/03-tenant-facility-module-prompt.md, prompts/02-subscriptions-module-prompt.md, prompts/24-hr-module-prompt.md, prompts/06-settings-profile-module-prompt.md
```
