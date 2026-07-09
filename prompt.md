# Platform Admin Dashboard — Management UX Refinement

## Context

Super-admin home dashboard (`127.0.0.1:5201`, Platform view) exposes four management entry points below the status cards. Screenshots show the current dialogs for **Manage tenants**, **Manage facilities**, and **Users and access** (Roles / Demo accounts tabs). These flows need clearer labeling, faster launch, full CRUD, and tighter UI consistency.

**Primary files**
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart`
- `frontend/lib/shared/dashboard/dashboard_priority_panel.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_management_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_dialogs.dart`
- `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`
- `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`

---

## 1. Dashboard — Rename the empty management section

**Problem:** The section that shows *"No follow-ups required."* with the four management buttons has no section title. The message describes queue state, not the actions below it.

**Required**
- Give this section an explicit title (e.g. **Platform management** or **Administration**) that reflects the four shortcuts: Manage tenants, Manage facilities, Manage roles and permissions, Manage users.
- Keep the empty-state message separate from the section title, or replace it with copy that fits an always-available admin shortcut panel.
- Update l10n (`app_en.arb`) for super-admin profile in `home_dashboard_profiles.dart`.

---

## 2. Manage Tenants dialog — Full CRUD + live UI

**Current behavior (screenshot):** Table with Tenant name, Tenant slug, Active. Footer: Refresh | Add tenant | Close. Row click opens edit form; save succeeds but the table does not reflect changes immediately.

**Required**
- **Edit:** After create/update, refresh the table in place without requiring manual Refresh. Invalidate or update local list state optimistically.
- **Delete:** Add delete action per row (with confirmation). Wire to `TenantFacilityRepository.deleteTenant`.
- **Remove Refresh button** — mutations and search/pagination should keep data current automatically.
- **Footer actions (left → right):** `Add tenant` (primary) → `Close` (secondary, with close icon e.g. `Icons.close`).
- Preserve search, pagination, responsive table (mobile/tablet/desktop), and permission gating (`canCreateTenant`).

---

## 3. Manage Facilities dialog — Full CRUD + “All” filter fix

**Current behavior (screenshot):** Tenant filter dropdown (All + per-tenant), search, table. Footer: Refresh | Add facility | Close.

**Required**
- **“All” filter:** When **All** is selected, list every facility across tenants (verify `listFacilities` with `tenantId: null` returns full paginated results).
- **Edit + Delete:** Same CRUD pattern as tenants. Wire delete to `TenantFacilityRepository.deleteFacility`.
- **Live UI:** Table updates immediately after create/edit/delete.
- **Remove Refresh button.**
- **Footer actions:** `Add facility` (primary) → `Close` (secondary, with close icon).
- Keep tenant filter, search, pagination, and responsive layout.

---

## 4. Split and simplify Users & Access

**Problem:** **Manage roles and access** and **Manage users** both open the same heavy **Users and access** dialog (`showAccessAdminWorkspaceDialog`) with seven tabs (Overview, User directory, Roles, Permissions, Module entitlements, Pending registrations, Demo accounts). Launch is slow; labels are misleading because both entry points feel identical.

**Required — two distinct dialogs**

| Dashboard action | New label | Scope |
|---|---|---|
| `manage_roles_access` | **Manage roles and permissions** | Roles list + permission assignment only. No user directory, demo accounts, or entitlements tabs. |
| `manage_users` | **Manage users** | Single searchable, paginated **users table** (ID, name, email/role details, status). Create, edit, deactivate/delete users inline or via row action. No tab bar. |

**Performance**
- Dialog must open instantly (< 300 ms perceived). Do **not** block on full workspace load.
- Lazy-load data per dialog scope (users-only vs roles-only).
- Show skeleton/inline loading in the table area, not a full-screen spinner.
- Avoid loading all panels/resources on open; refactor `AccessAdminWorkspaceController.build()` / `_loadInitialState` if needed.

**Rename & align copy**
- Update action labels in `home_dashboard_actions.dart` and l10n keys.
- Dialog titles must match dashboard action intent (not generic “Users and access” for both).
- Remove or hide tabs that are out of scope for each entry point.

---

## 5. Cross-cutting UX rules

- **Responsive:** All dialogs and tables must work on mobile, tablet, and desktop (`AppListTable`, `AppDialog`, existing breakpoints).
- **Consistency:** Match existing HOSSPI patterns — `AppButton.primary/secondary`, `AppSearchBar`, `AppDialog` with `pinActionsToBottom`, confirmation before destructive actions.
- **No manual refresh:** Prefer automatic list invalidation after mutations across all three management dialogs.
- **Permissions:** Respect existing `AppAccessPolicy` checks; hide create/delete where unauthorized.
- **Tests:** Add/update widget or controller tests for list refresh after edit, delete confirmation, and split access-admin entry points.

---

## Acceptance criteria

- [ ] Super-admin dashboard section has a clear **Platform management** (or equivalent) title; buttons sit under it, not under a queue-empty message alone.
- [ ] Manage Tenants: edit updates table immediately; delete works; no Refresh button; Close has icon.
- [ ] Manage Facilities: **All** shows all facilities; full CRUD; no Refresh button; Close has icon.
- [ ] Manage roles and permissions opens a focused roles/permissions dialog — fast, no irrelevant tabs.
- [ ] Manage users opens a single user-table dialog — fast, no tab bar.
- [ ] Dashboard action labels match dialog content; no duplicate “Users and access” experience.
- [ ] All changes are l10n-ready and responsive across breakpoints.
