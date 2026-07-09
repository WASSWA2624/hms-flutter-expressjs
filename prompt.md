# Platform Admin Dashboard — Quick Actions & Management Dialogs

## Context

The super-admin home dashboard layout is acceptable. The remaining work is to **wire up and synchronize** platform-administration actions so Quick Actions and the Follow-ups panel open the correct modal workflows, support full CRUD, and work end-to-end against the backend.

**Current issues (see screenshots):**
- **Quick Actions** shows three overlapping actions (`Select tenant/facility`, `Create tenant`, `Create facility`) that route to the same setup page instead of focused create dialogs.
- **Follow-ups** (empty state: “No follow-ups required”) duplicates Quick Action buttons instead of offering management shortcuts.
- **Tenant Profile** and **Facility Profile** saves fail with **“Enter a valid Id.”** when saving existing records (e.g. DemoCare General Hospital) — likely a UUID vs friendly-ID mismatch on update routes, or a missing/invalid `id` on PUT.
- **Branches** management UI exists but is empty; nested actions (add branch, etc.) must work from management dialogs.

## Goal

Refactor the **platform admin** (`AppRole.superAdmin`) dashboard so:

1. **Quick Actions** = four **create** shortcuts (modal dialogs).
2. **Follow-ups panel empty state** = four **manage** shortcuts (list dialogs with tables, filters, and CRUD).
3. All flows are **backend-synchronized**, **permission-gated**, and **reusable** by tenant admin / facility admin where applicable.

---

## Quick Actions (create shortcuts)

Replace current super-admin quick actions with these four. Each opens a **modal dialog** (not full-page navigation). Reuse existing dialog patterns where possible (`showAppDialog`, `_SetupDetailDialog`, `showHrStaffOnboardingDialog`, etc.).

| Action | Behavior |
|--------|----------|
| **Create tenant** | Modal form: tenant name, optional slug, contact fields as needed. On create: account is **auto-verified** (no email verification step). Platform-admin–created tenants skip self-registration verification. |
| **Create facility** | Modal form: facility details (name, type, phone, address, logo, active). **Require tenant selection** first (dropdown/search of existing tenants). Creating a facility is separate from creating a tenant. |
| **Create role** | Modal to define a new role / access level (name, description, permissions). Reuse or extend HR access role dialogs (`showHrCreateRoleDialog` pattern). |
| **Create user** | Modal to onboard a user and **assign role(s)**. Reuse or extend staff/user onboarding (`showHrStaffOnboardingDialog` pattern). Support attaching roles during creation. |

**Remove** `Select tenant/facility` from Quick Actions — context selection belongs in management dialogs or the app shell, not as a primary create shortcut.

Update `homeDashboardProfiles` → `AppRole.superAdmin.quickActionIds` and `homeActionLibrary` / `homeInvokeAction` handlers accordingly.

---

## Follow-ups panel → Management shortcuts

When the follow-ups queue is empty, show **management shortcuts** (not duplicate create buttons):

| Shortcut | Opens |
|----------|-------|
| **Manage tenants** | Dialog with searchable/filterable **tenant table**. Row actions: view, edit, activate/deactivate, delete (where permitted). Footer: Close, primary actions as needed. Support **nested dialogs** for edit/create/detail (e.g. edit tenant profile, add branch under a tenant). |
| **Manage facilities** | Dialog with facility table (filter by tenant, status, type). Row actions: view, edit, activate/deactivate, delete. Nested dialogs for facility profile, branches, departments, etc. |
| **Manage roles & access** | Dialog with roles/permissions tables. CRUD for roles and permission assignment. Reuse `showHrAccessWorkspaceDialog` / access-admin patterns where possible. |
| **Manage users** | Dialog with users table (filters: tenant, facility, role, status). CRUD + role assignment. Nested dialogs for user detail and role attachment. |

**Dialog requirements:**
- Search bar + column filters (match existing `AppSearchBar` / `AppListTable` patterns).
- Paginated table with footer actions (Close, Save, Add, etc.).
- **Nested dialog support** — an action inside a management dialog opens a child dialog without losing parent context.
- Responsive on mobile, tablet, and desktop.

Update `homeDashboardProfiles` → `AppRole.superAdmin.emptyActionIds` (and related mapper wiring in `home_dashboard_mapper.dart`).

---

## Bug fixes (blocking)

### 1. “Enter a valid Id.” on tenant/facility save

Fix save failures on **Tenant Profile** and **Facility Profile** forms:
- Investigate `tenant_facility_setup_page.dart` → `saveTenant` / `saveFacility` and `tenant_facility_repository_impl.dart`.
- Backend tenant/facility **param schemas** use `uuidSchema` (`backend/src/modules/tenant/schemas`, `facility/schemas`) while the app may use **friendly IDs** (e.g. `TEN0001`). Align on `uuidOrFriendlyIdentifierSchema` for route params, or ensure the frontend always sends the correct identifier format.
- Ensure **create** uses POST without `id`; **update** uses PUT only when a valid `id` is present.
- Map API validation errors to user-friendly field labels (not generic “Id”).

### 2. Clear stale errors

Dismiss validation/error messages when dialogs open, close, or when the user edits fields.

---

## Backend ↔ frontend synchronization

- All create/update/delete operations must call existing REST endpoints (`/tenants`, `/facilities`, `/branches`, access-admin / HR user-role APIs).
- After successful mutations, refresh dashboard metrics (tenants, facilities, subscriptions, entitlements) and any open management dialog lists.
- Respect `AppAccessPolicy` / `AppPermission` gates (`systemAdmin`, `tenantAdmin`, `facilityAdmin`).

---

## Reusability & roles

- Implement dialogs and actions as **shared, reusable widgets** under `tenant_facility`, `access_admin`, and/or `shared/` — not super-admin-only.
- Gate visibility via `HomeActionDefinition` permissions and `allowedRoles` so tenant admin and facility admin can reuse the same components where their permissions overlap.
- Platform admin sees all four quick actions and all four management shortcuts; other roles see subsets per existing permission model.

---

## Key files

| Area | Files |
|------|-------|
| Dashboard config | `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` |
| Action handlers | `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` |
| Dashboard mapping | `frontend/lib/features/home/presentation/widgets/home_dashboard_mapper.dart` |
| Tenant/facility UI | `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart` |
| Access / roles / users | `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart`, `frontend/lib/features/access_admin/` |
| Backend schemas | `backend/src/modules/tenant/schemas/`, `backend/src/modules/facility/schemas/` |

---

## Acceptance criteria

- [ ] Super-admin Quick Actions shows exactly: **Create tenant**, **Create facility**, **Create role**, **Create user** — each opens the correct modal.
- [ ] Empty Follow-ups panel shows: **Manage tenants**, **Manage facilities**, **Manage roles & access**, **Manage users** — each opens a filterable table dialog with CRUD.
- [ ] Nested dialogs work (e.g. Manage tenants → edit tenant → add branch).
- [ ] Tenant and facility profile saves succeed for both new and existing records (no “Enter a valid Id.”).
- [ ] Branches can be added and listed from facility/tenant management flows.
- [ ] Dashboard metric cards refresh after mutations.
- [ ] Components are permission-gated and reusable by tenant/facility admins where applicable.
- [ ] UI is responsive on mobile, tablet, and desktop.
