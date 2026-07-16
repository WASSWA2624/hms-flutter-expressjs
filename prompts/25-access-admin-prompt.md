# Standardize Access Admin Tables

## Objective

Refactor every `AppListTable` on the Access Admin workspace (`/admin/access`, `AccessAdminWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only** on the `/admin/access` workspace route. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation. Preserve tab toolbar primary/secondary actions (Create user, Create role, Refresh), tenant-context gate, deep-link query handling (`?panel=<value>`, `resource`, `search`, `status`, `roleScope`), pagination, and `accessAdminWorkspaceControllerProvider` reload semantics.

**Out of scope:** `AppListTable` instances inside `access_admin_management_dialogs.dart` (`showManageUsersDialog`, `showManageRolesPermissionsDialog`) — those are home/settings dialogs, not this screen. Use them only as reference for Filters/Settings wiring.

## Current State (from audit)

### Screen layout

| Item | Value |
|------|-------|
| Route | `/admin/access` (`AppRoutes.accessAdmin`) |
| Page widget | `AccessAdminWorkspacePage` |
| Primary file | `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart` |
| Controller | `accessAdminWorkspaceControllerProvider` (`AccessAdminWorkspaceController`) |
| Entity | `AccessAdminItem` (`frontend/lib/features/access_admin/domain/entities/access_admin_entities.dart`) |
| Deep-link query | `panel`, `resource`, `search`, `status`, `roleScope`, `tenantId`, `facilityId`, `recordId` via `AccessAdminWorkspaceQuery.fromUri` |
| Realtime | `listenForRealtimeRefresh(events: RealtimeEventGroups.accessAdmin)` + `AccessAdminRealtimeDeltaApplier` in controller |

### Tabs (`AccessAdminPanel`) → default resource (`AccessAdminResource`)

| Panel | l10n key | Default resource | Toolbar create action | Tenant context required |
|-------|----------|------------------|----------------------|-------------------------|
| Overview | `accessAdminPanelOverview` | `users` | Create user (if `canWrite`) | Yes |
| Directory | `accessAdminPanelDirectory` | `users` | Create user | Yes |
| Roles | `accessAdminPanelRoles` | `roles` | Create role | Yes |
| Permissions | `accessAdminPanelPermissions` | `permissions` | None | Yes |
| Entitlements | `accessAdminPanelEntitlements` | `moduleEntitlements` | None | Yes |
| Registrations | `accessAdminPanelRegistrations` | `registrationFollowUps` | None | **No** (elevated admin only) |
| Demo | `accessAdminPanelDemo` | `demoUsers` | Create user | Yes |

Registrations tab visibility: gated by `appAccessPolicyProvider.isElevated` in `_AccessAdminPanelTabBar`.

### Table inventory

There is **one** `AppListTable` on this screen — `_WorklistPanel` — reused for all tabs. Column set branches only on `state.query.resource == AccessAdminResource.roles` vs all other resources.

| Table widget | Tab / panel | Entity | `columnVisibilityStorageKey` today | `columnWidthStorageKey` today |
|--------------|-------------|--------|-----------------------------------|------------------------------|
| `_WorklistPanel` | All panels (resource-driven) | `AccessAdminItem` | **none** | **none** |

### Per-resource current columns (4 declared; no column `id`; no `sortComparator`)

**Roles** (`AccessAdminResource.roles`):

| # | Label (l10n) | Field | Cell pattern |
|---|--------------|-------|--------------|
| 1 | `accessAdminColumnId` | `effectiveDisplayId` | `Text` |
| 2 | `accessAdminColumnName` | `title` | `Text` |
| 3 | `accessAdminColumnScope` | `isFacilityScopedRole`, `facilityName`, `roleScope` | `Chip` + icon |
| 4 | `accessAdminColumnDetails` | `subtitle` (role description) | `Text` or `'—'` |

**All other resources** (users, demoUsers, permissions, moduleEntitlements, registrationFollowUps):

| # | Label | Field | Cell pattern |
|---|-------|-------|--------------|
| 1 | ID | `effectiveDisplayId` | `Text` |
| 2 | Name | `title` | `Text` |
| 3 | Details | `subtitle` | `Text` or `'—'` |
| 4 | Status | `status` | **Raw** `Text(item.status ?? '—')` — no `AppWorkspaceStatusBadge` |

**Entity field mapping by resource** (from `AccessAdminItemDto`):

| Resource | `title` source | `subtitle` source | Notable fields |
|----------|----------------|-------------------|----------------|
| `users` / `demoUsers` | `profile_name` ?? `email` | `position_title` | `email`, `phone`, `facilityName`, `roles`, `status`, `isDemo`, `staffProfileId` |
| `roles` | `display_name` ?? `name` | `description` | `userCount`, `permissionCount`, `isSystemCritical`, scope |
| `permissions` | `display_name` ?? `name` | `description` | `permissionName`, `status` |
| `moduleEntitlements` | `module_label` ?? `module_slug` | `module_group` | `planLabel`, `isActive`, `entitlementDenied`, `entitlementDenialReason` |
| `registrationFollowUps` | `admin_name` ?? `tenant_name` ?? `email` | `facility_name · facility_type` | `status`, `email` |

### Search chrome gaps (`_WorklistPanel`)

| Area | Current | Gap vs `prompt.md` |
|------|---------|---------------------|
| Search matcher | Client-side: `title`, `effectiveDisplayId`, `subtitle`, `email`, `name` | Misses `status`, scope labels, `facilityName`, `roles`, `permissionName`, `moduleSlug`, `planLabel`, entitlement fields |
| Filters | Inline `filterGroups` for **users only** (`status`); no Advanced filters modal | Must use `showAdvancedFilterButton: true`; modal title **Advanced filters**; move status filter into modal |
| Filters label | N/A (inline chips) | Must be `Filters` (`accessAdminFiltersAction` or shared `commonFiltersActionLabel`) |
| Settings | **Missing** | Must add `columnVisibilityLabel: l10n.commonTableSettingsActionLabel`, `columnVisibilityTitle` → **Table Settings** |
| Column visibility persistence | **Missing** | Need `AppListTableColumnVisibilityController` + per-resource `columnVisibilityStorageKey` |
| `columnChoices` | **Not used** | Required for hidden lower-priority columns |
| Extra search chrome actions | None | OK |
| `displayMode` | Default `AppListTableDisplayMode.adaptive` | OK |

### Column / interaction gaps

| Gap | Detail |
|-----|--------|
| Tab-specific triage columns | Permissions, Entitlements, Registrations use generic user-like columns (name/details/status) |
| Status formatting | Raw API strings; must use `AppWorkspaceStatusBadge` where `status` exists |
| Next-action column | **Missing**; write actions only in `_DetailContent._actions` |
| Row selection | `onRowSelected` → `_openDetailDialog` → `AppDialog` + `_DetailContent` | Opens dialog ✓ but permissions/entitlements lack dedicated detail sections |
| Mobile | `ListTile` with plain status text; no next-action control |
| `sortComparator` | **None** on any column |
| Column `id` | **None** — required for visibility/sort keys |
| Realtime | `accessAdminWorkspaceControllerProvider` + `AccessAdminRealtimeDeltaApplier` | OK — do not break |

### Domain actions (from `_DetailContent._actions` and dialog actions)

**Users / demo users** (`canWrite`):

| Condition | Action label (l10n) | Handler |
|-----------|---------------------|---------|
| `status == 'ACTIVE'` | `accessAdminDeactivateAction` | `controller.setUserStatus(item, 'INACTIVE')` |
| else | `accessAdminActivateAction` | `controller.setUserStatus(item, 'ACTIVE')` |
| `isDemo && canResetDemoPasswords` | `accessAdminResetDemoPasswordAction` | `controller.resetDemoPassword(item)` |

**Roles** (dialog actions bar, `canWrite && !isSystemCritical`):

| Action | Label | Handler |
|--------|-------|---------|
| Edit | `accessAdminEditRoleAction` | `openAccessAdminEditRoleDialog` |
| Delete | `accessAdminDeleteRoleAction` | `_confirmDeleteRole` |

**Registrations** (`canWrite`):

| Action | Label | Handler |
|--------|-------|---------|
| Primary | `accessAdminActivateRegistrationAction` | `controller.activateRegistration(item)` |
| Secondary | `accessAdminRejectRegistrationAction` | `controller.rejectRegistration(item)` |

**Permissions / entitlements:** Read-only catalog rows — no write next-action; use a fifth **data** column instead of workflow action.

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`, `AppListTableColumnVisibilityMemory`, `appListTableCompareText`
- `frontend/lib/shared/components/app_list_item_text.dart` — `AppListItemText` for two-line single-field cells
- `frontend/lib/shared/components/app_status_badge.dart` — `AppWorkspaceStatusBadge`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome, `columnChoices`, `columnVisibilityController`, `_matchesSearch`, mobile item)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` structure (adapt with `AppButton.tertiary` opening same dialogs as detail actions — Access Admin does **not** use `WorkflowActionButton`)
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart` — `_ScopedAccessAdminListDialogState.buildTable` / `buildTableSearch` (Filters modal + Settings pattern; role scope filter groups)
- `prompt.md`

## Target Architecture

### Table inventory (after refactor)

Use **per-resource** storage keys because one `_WorklistPanel` widget switches columns when `state.query.resource` changes:

| Table widget | Resource / tab context | Entity | Default visible columns (max 5) | `columnVisibilityStorageKey` | `columnWidthStorageKey` |
|--------------|------------------------|--------|----------------------------------|------------------------------|-------------------------|
| `_WorklistPanel` | `users` (Overview + Directory) | `AccessAdminItem` | ID, Name, Facility, Status, Next action | `access_admin_workspace_users_v1` | `access_admin_cw_users_v1` |
| `_WorklistPanel` | `demoUsers` | `AccessAdminItem` | ID, Name, Facility, Status, Next action | `access_admin_workspace_demo_users_v1` | `access_admin_cw_demo_users_v1` |
| `_WorklistPanel` | `roles` | `AccessAdminItem` | ID, Name, Scope, Users, Next action | `access_admin_workspace_roles_v1` | `access_admin_cw_roles_v1` |
| `_WorklistPanel` | `permissions` | `AccessAdminItem` | ID, Name, Description, Permission code, Status | `access_admin_workspace_permissions_v1` | `access_admin_cw_permissions_v1` |
| `_WorklistPanel` | `moduleEntitlements` | `AccessAdminItem` | Module, Group, Plan, Active, Denial | `access_admin_workspace_entitlements_v1` | `access_admin_cw_entitlements_v1` |
| `_WorklistPanel` | `registrationFollowUps` | `AccessAdminItem` | ID, Name, Facility, Status, Next action | `access_admin_workspace_registrations_v1` | `access_admin_cw_registrations_v1` |

Instantiate one `AppListTableColumnVisibilityController<AccessAdminItem>` per resource key in `_AccessAdminWorkspaceContentState` (mirror Mortuary's `tableColumnController`), or recreate controller when resource changes while preserving session memory via storage keys.

### Column plan — Users / Demo users

| Position | Column id | Label (l10n) | Source field | Notes |
|----------|-----------|--------------|--------------|-------|
| 1 | `user_id` | `accessAdminColumnId` | `effectiveDisplayId` | `alwaysVisible: true`; `sortComparator` via `appListTableCompareText` |
| 2 | `user_name` | `accessAdminColumnName` | `title` | `AppListItemText(title: title, subtitle: email)` when email differs from title (single field) |
| 3 | `user_facility` | `accessAdminColumnFacility` | `facilityName` ?? `facilityId` | |
| 4 | `status` | `accessAdminColumnStatus` | `status` | `AppWorkspaceStatusBadge(status: item.status!)` when non-null |
| 5 | `next_action` | `accessAdminManageUserAction` (add) | derived | `canWrite`: `ACTIVE` → `accessAdminDeactivateAction`; else `accessAdminActivateAction`; opens same path as row tap |

**`columnChoices`:** `user_details` (`subtitle` / position), `user_roles` (joined `roles[].name`), `user_email`, `user_phone`, `user_tenant` (`tenantName`)

### Column plan — Roles

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `role_id` | ID | `effectiveDisplayId` | `alwaysVisible: true` |
| 2 | `role_name` | Name | `title` | |
| 3 | `role_scope` | Scope | scope fields | Reuse existing `Chip` cell (extract `_RoleScopeBadge` from management dialogs or duplicate minimal chip) |
| 4 | `role_users` | `accessAdminRoleDetailUsersLabel` | `userCount` | `Text('${item.userCount}')` |
| 5 | `next_action` | `accessAdminEditRoleAction` | derived | `canWrite && !isSystemCritical` → tertiary button → `openAccessAdminEditRoleDialog`; else empty/read-only |

**`columnChoices`:** `role_details` (`subtitle`), `role_permissions` (`permissionCount` formatted with `hrAccessPermissionCountLabel`)

### Column plan — Permissions (no workflow — five data columns)

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `perm_id` | ID | `effectiveDisplayId` | |
| 2 | `perm_name` | Name | `title` | |
| 3 | `perm_description` | Details | `subtitle` | |
| 4 | `perm_code` | `permissionCatalogLabelForCode` or reuse `accessAdminColumnDetails` | `permissionName` ?? `name` | Use `permissionCatalogLabelForCode` in cell when code present |
| 5 | `perm_status` | Status | `status` | `AppWorkspaceStatusBadge` or `'—'` |

**`columnChoices`:** none required unless audit finds extra API fields worth exposing

### Column plan — Module entitlements (no workflow)

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `ent_module` | Name | `title` | module label |
| 2 | `ent_group` | Details | `moduleGroup` ?? `subtitle` | |
| 3 | `ent_plan` | add `accessAdminEntitlementPlanColumnLabel` | `planLabel` | |
| 4 | `ent_active` | Status | `isActive` | Badge: active/inactive (format `isActive` boolean — add small helper `_entitlementActiveLabel`) |
| 5 | `ent_denial` | add `accessAdminEntitlementDenialColumnLabel` | `entitlementDenialReason` | Show denial reason when `entitlementDenied` |

**`columnChoices`:** `ent_module_slug` (`moduleSlug`)

### Column plan — Registrations (workflow-style approve/reject)

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `reg_id` | ID | `effectiveDisplayId` | |
| 2 | `reg_name` | Name | `title` | |
| 3 | `reg_facility` | Details | `subtitle` | facility line |
| 4 | `status` | Status | `status` | `AppWorkspaceStatusBadge` |
| 5 | `next_action` | `accessAdminActivateRegistrationAction` | derived | `canWrite` → primary tertiary button → `controller.activateRegistration(item)`; reject stays in detail dialog |

**`columnChoices`:** `reg_email` (`email`)

### Search chrome (per resource)

Refactor `_WorklistPanel` to delegate search/columns to helpers (e.g. `_accessAdminColumnsForResource`, `_accessAdminSearchMatcher`, `_accessAdminFilterGroups`) in the same file or a new `access_admin_workspace_table.dart` part file if the page exceeds ~1200 lines.

**Matcher** — implement `_accessAdminSearchMatcher(BuildContext context, AccessAdminResource resource, AccessAdminItem item, String query)` covering **all** default + `columnChoices` fields for the active resource (lowercase `contains`), including formatted status labels, scope badge text, joined role names, permission catalog labels, entitlement active/denial text.

Keep `onSubmitted` / `onClear` calling `controller.applySearch` (server-side search preserved).

**Standardize chrome:**

| Control | Wiring |
|---------|--------|
| Filters label | `advancedFilterButtonLabel: l10n.accessAdminFiltersAction` (`"Filters"`) or add `commonFiltersActionLabel` |
| Filters modal title | `advancedFilterTitle: l10n.commonAdvancedFiltersTitle` (add key `"Advanced filters"`) — replace per-screen `accessAdminFiltersTitle` / `accessAdminUsersFiltersTitle` on workspace |
| Settings label | `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` |
| Settings modal title | `columnVisibilityTitle: l10n.commonTableSettingsTitle` (add key `"Table Settings"`) |
| Apply/reset | `advancedFilterApplyLabel: l10n.opdApplyFiltersAction`, `advancedFilterResetLabel: l10n.opdClearFiltersAction` |

**Filter groups by resource:**

| Resource | Filter groups | `onFilterChanged` |
|----------|---------------|-------------------|
| `users`, `demoUsers` | `status` (existing choices from `state.data.lookups.userStatuses`) | `controller.applyStatusFilter` (existing) |
| `roles` | `role_scope` with choices from management dialog pattern (`accessAdminRoleScopeFilterAll`, `accessAdminRoleScopeFilterTenant`, `accessAdminRoleScopeFilterFacility`) | **Add** `AccessAdminWorkspaceController.applyRoleScopeFilter(String? roleScope)` mirroring query `roleScope` field + repository reload (copy logic from `_ManageRolesPermissionsDialogState` filter handler) |
| `permissions`, `moduleEntitlements`, `registrationFollowUps` | `const <AppSearchBarFilterGroup>[]` | Still set `showAdvancedFilterButton: true` for compliance; modal opens with no groups (verify `AppSearchBar` handles empty groups gracefully) |

Move status filter **out of inline chips** into Advanced filters modal (`showAdvancedFilterButton: true`).

Wire on `AppListTable`:

```dart
columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
columnVisibilityTitle: l10n.commonTableSettingsTitle,
columnVisibilityStorageKey: _storageKeyForResource(state.query.resource),
columnWidthStorageKey: _widthStorageKeyForResource(state.query.resource),
columnVisibilityController: columnController, // when using explicit controller
columnChoices: allColumnsForResource, // superset
columns: defaultVisibleColumnsForResource, // ≤5
```

### Next-action column implementation

Add helper mirroring Emergency's factory pattern:

```dart
AppListTableColumn<AccessAdminItem> _accessAdminNextActionColumn(
  BuildContext context, {
  required AccessAdminResource resource,
  required bool canWrite,
  required ValueChanged<AccessAdminItem> onAction,
}) { ... }
```

Use `AppButton.tertiary` with `alwaysVisible: true` (match management dialog actions column). Gate with `canWrite` and resource-specific rules (`!isSystemCritical` for roles). **Same handler destination** as `_DetailContent._actions` / dialog action bar.

### Row interaction

- Keep `onRowSelected` → `_openDetailDialog` (do not navigate away).
- **Extend** `_DetailContent` (same file) for:
  - `AccessAdminResource.permissions`: show permission code (`permissionCatalogLabelForCode`), description, status — read-only.
  - `AccessAdminResource.moduleEntitlements`: show module, group, plan, active flag, denial reason — read-only.
- Do **not** route workspace row tap to `_AccessAdminUserDetailDialog` / `_AccessAdminRoleDetailDialog` from management dialogs (different data-loading lifecycle); enhance inline `_DetailContent` instead.

### Mobile (`mobileItemBuilder`)

Replace generic `ListTile` with `_AccessAdminMobileListItem` widget that mirrors desktop priority fields per resource:

- Show ID/name, formatted status badge (when applicable), scope chip (roles), and next-action button (when `canWrite`).
- `onTap` → `onItemSelected` (detail dialog).

Follow `_MortuaryMobileListItem` structure in mortuary workspace page.

## Implementation Steps

### 1. Controller — role scope filter (roles tab only)

**File:** `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart`

- Add `Future<AppFailure?> applyRoleScopeFilter(String? roleScope)` updating `state.query.copyWith(roleScope: roleScope)` and reloading (same pattern as `applyStatusFilter`).
- Ensure `AccessAdminWorkspaceQuery.location()` serializes `roleScope` (already present).

### 2. Workspace state — column visibility controllers

**File:** `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`

- In `_AccessAdminWorkspaceContentState`, add `AppListTableColumnVisibilityController<AccessAdminItem>` instances keyed by `AccessAdminResource` (or one controller swapped with correct `columnVisibilityStorageKey` on resource change).
- Pass controller + storage keys into `_WorklistPanel`.

### 3. Refactor `_WorklistPanel`

**File:** `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`

- Extract `_accessAdminDefaultColumns`, `_accessAdminColumnChoices`, `_accessAdminSearchMatcher`, `_accessAdminFilterGroups`, `_accessAdminMobileListItem` helpers.
- Add column `id` and `sortComparator` (`appListTableCompareText`) on every column.
- Wire standardized search chrome (Advanced filters + Table Settings).
- Switch `columns` / `columnChoices` / storage keys by `state.query.resource`.
- Add next-action column for users, demo users, roles, registrations.
- Replace raw status `Text` with `AppWorkspaceStatusBadge`.

### 4. Extend `_DetailContent`

**File:** same

- Add branches for `AccessAdminResource.permissions` and `AccessAdminResource.moduleEntitlements` with read-only field rows (`_DetailRow`).
- Preserve existing user/role/registration behavior.

### 5. l10n

**File:** `frontend/lib/l10n/app_en.arb` only

Add if missing:

| Key | English value |
|-----|---------------|
| `commonAdvancedFiltersTitle` | `Advanced filters` |
| `commonTableSettingsTitle` | `Table Settings` |
| `commonFiltersActionLabel` | `Filters` (optional if `accessAdminFiltersAction` reused) |
| `accessAdminManageUserAction` | `Manage user` |
| `accessAdminEntitlementPlanColumnLabel` | `Plan` |
| `accessAdminEntitlementDenialColumnLabel` | `Denial` |
| `accessAdminNextActionColumnLabel` | `Action` (column header only if needed; cell buttons use explicit verbs per `prompt.md` §4) |

Run code generation: `cd frontend && dart run flutter_gen` or project-standard l10n codegen.

### 6. Tests

**Add:** `frontend/test/features/access_admin/presentation/access_admin_workspace_table_test.dart`

- Pump `_WorklistPanel` (or extracted helpers) with fake `AccessAdminWorkspaceState` per resource.
- Assert ≤5 default columns, presence of `columnVisibilityStorageKey`, search matcher hits hidden fields, next-action labels for registrations (`Activate account`).
- Assert Filters button uses Advanced filters title and Settings uses Table Settings title.

**Preserve:** existing tests under `frontend/test/features/access_admin/`.

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumnVisibilityController` | `package:hosspi_hms/shared/components/app_list_table.dart` | Session column visibility |
| `appListTableCompareText` | `package:hosspi_hms/shared/components/app_list_table.dart` | Sort comparators |
| `AppListItemText` | `package:hosspi_hms/shared/components/app_list_item_text.dart` | Two-line name/email cell |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/components/app_status_badge.dart` | Status column |
| `AppButton.tertiary` | `package:hosspi_hms/shared/components/components.dart` | Next-action column |
| `AppPermissionGroupedView` | `package:hosspi_hms/shared/components/components.dart` | Role detail (existing) |
| `AppUserAccessPanel` | shared components | User detail (existing) |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart` |
| Modify | `frontend/lib/features/access_admin/presentation/controllers/access_admin_workspace_controller.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Create | `frontend/test/features/access_admin/presentation/access_admin_workspace_table_test.dart` |
| Optional create | `frontend/lib/features/access_admin/presentation/widgets/access_admin_workspace_table.dart` (if extracting helpers reduces page size) |
| Do not modify | `access_admin_management_dialogs.dart` (out of scope) |

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/access_admin/
```

## Testing Requirements

- [ ] Each resource tab: search, Filters, Settings only in chrome (no export/refresh in search bar)
- [ ] Column visibility persists for session per `columnVisibilityStorageKey`
- [ ] ≤5 default columns; row number automatic
- [ ] Registrations: explicit status + `Activate account` next-action
- [ ] Users/demo: status badge + Activate/Deactivate next-action when `canWrite`
- [ ] Roles: Edit next-action when `canWrite && !isSystemCritical`
- [ ] Permissions/entitlements: five data columns, no generic action column
- [ ] Row tap opens detail dialog; permissions/entitlements show read-only detail
- [ ] Mobile list shows same priority fields + next-action where applicable
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `canWrite` / tenant-context gates still suppress write actions

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for `_WorklistPanel` on every Access Admin tab/resource
- [ ] Domain logic preserved (create user/role, activate/reject registration, role edit/delete, user status)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/access_admin/` passes
