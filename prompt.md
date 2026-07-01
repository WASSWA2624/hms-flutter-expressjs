# HR Staff Access Modal — Table UX, Detail Dialogs & Permission Catalog

## Objective

Refine the **Staff access** modal in the HR workspace (`/hr`) so it is visually and behaviorally consistent with the HR staff directory and other admin workspaces. Fix broken detail/create flows, make tables fully scrollable with integrated search/filter/settings, wire staff/role/permission detail dialogs end-to-end, and introduce a canonical permission catalog with reusable pickers used consistently across HR and access-admin surfaces.

**Entry point:** HR workspace → More actions (⋮) → **Manage users and roles** → `Staff access` modal.

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md), [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md)

**Primary touchpoints:**

| Area | File |
|------|------|
| Staff access modal (tabs, tables, actions) | `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart` |
| More-actions menu entry | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` |
| Staff directory table reference | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` (`AppListTable<HrStaffProfile>`) |
| Staff onboarding / create flow | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` |
| HR repository (API `limit` params) | `frontend/lib/features/hr/data/repositories/hr_repository_impl.dart` |
| Access entities | `frontend/lib/features/hr/domain/entities/hr_entities.dart` |
| Canonical permission catalog | `frontend/lib/core/permissions/access_policy.dart` (`AppPermissions`) |
| Reusable role picker | `frontend/lib/shared/components/app_role_assignment_picker.dart` |
| Strings | `frontend/lib/l10n/app_en.arb` |

---

## Problem Statement (from current UI)

The Staff access modal is partially migrated to `AppListTable` but remains inconsistent with the HR staff directory and has functional gaps visible in the attached screenshots:

1. **Table layout mismatch** — Staff/Roles/Permissions use a standalone `AppTextField` search above the table instead of the integrated `AppListTableSearch` toolbar (search, filter, column settings) used by the HR staff directory. Pagination sits bottom-right but the table body does not fill available height, so only ~5 rows are visible while the label reads **1–12 of 20**.
2. **Non-uniform tabs** — Panel tabs should use square-edged `AppWorkspaceBoardToggle` styling with no pill radius or selected checkmark icon (match workspace board toggles elsewhere).
3. **Staff detail dialog broken** — Clicking a staff row opens **User account** with error **"Invalid value for limit"** instead of profile details. Root cause: API calls pass `limit: 200` while backend `MAX_PAGE_LIMIT` is **100** (`hr_repository_impl.dart` → `listUserRoles`, `listRolePermissions`).
4. **Sparse staff table data** — Staff column shows email only; **Assigned roles** shows "Not available" because role names are not hydrated on list rows. Detail dialog should show name, email, phone, position, status, linked staff profile, assigned roles, and direct permissions.
5. **Roles tab incomplete** — Role list shows "No permissions" / "No staff" / "Not available" for counts that should reflect backend aggregates. Role detail modal works but should refresh after assign/edit without closing the parent modal.
6. **Permissions are free-text** — Create/edit permission dialogs use a plain `AppTextField` for the permission name. Users should pick from a **pre-defined, searchable catalog** (`AppPermissions.all`) and only supply an optional description override.
7. **Permission pickers load one page** — Assign-permissions and edit-user flows call `loadAccessPermissions` with default `pageSize: 12`, so only the first page of ~61 permissions is selectable.
8. **No shared permission picker** — `AppRoleAssignmentPicker` exists but permission multi-select is duplicated inline. Extract a reusable `AppPermissionAssignmentPicker` (or equivalent) and use it in role assign, user edit, and future access-admin screens.
9. **Stale UI after mutations** — Changes to roles, permissions, or staff accounts should refresh the active panel (and open detail dialogs when applicable) without requiring a manual full-page refresh.

---

## Global Standards

Follow the same rules as the HR module prompt:

- Hospital workflow language — show names, staff numbers, role labels, and status badges; never raw UUIDs in primary UI.
- Modal-first: all create/edit/detail flows use `AppDialog` / `showAppWorkspaceMutationDialog`.
- Reuse `frontend/lib/shared/*` components; follow `frontend/.cursor/design-system.mdc` and `ui-patterns.mdc`.
- Match the **HR staff directory** table patterns (`AppListTable`, `AppListTableSearch`, `_CopyableIdentifierCell`, `AppStatusText`, pagination labels).
- All new/changed strings in `frontend/lib/l10n/app_en.arb`.
- Permission-gate write actions with `canWriteHrAccess(ref)`; respect `hrWrite` permission.
- Refresh the active panel after every mutation via existing `_reload(resetPage: true)`.
- Responsive: tables must work on mobile (list layout), web, and desktop with the same component API.

---

## 1. Modal Shell & Tabs

### 1.1 Maximized, resizable dialog

Keep / verify `_HrAccessWorkspaceDialog` configuration:

| Property | Required value |
|----------|----------------|
| `initialMaximized` | `true` |
| `resizable` | `true` |
| `showMaximizeButton` | `true` |
| `scrollable` | `true` |

Content `Column` must use `Expanded` around the table so the table body scrolls inside the dialog viewport (do not use `mainAxisSize: MainAxisSize.min` on the table wrapper).

### 1.2 Square panel tabs

Use `AppWorkspaceBoardToggle<HrAccessPanel>` with `showSelectedIcon: false` and `theme.radius.sm` corner radius — **no pill-shaped segments or checkmark icons**.

Tab labels: **Staff** | **Roles** | **Permissions** (not "Users").

---

## 2. Unified Table Pattern (all three panels)

Replace the standalone search `AppTextField` above each table with the same integrated pattern as `_HrStaffDirectoryPanel` in `hr_workspace_page.dart`:

```dart
AppListTable<T>(
  search: AppListTableSearch<T>(
    controller: _searchController,
    semanticLabel: l10n.hrAccessSearchLabel,
    hintText: l10n.hrAccessSearchHint,
    clearLabel: l10n.hrClearFiltersAction,
    matcher: (_, _) => true, // server-side search via debounced _reload
    onSubmitted: (_) => unawaited(_reload(resetPage: true)),
    onClear: () { _searchController.clear(); unawaited(_reload(resetPage: true)); },
    // column visibility via table's columnVisibilityController
  ),
  columnVisibilityController: _columnVisibilityController,
  columnVisibilityLabel: l10n.commonTableSettingsActionLabel,
  // DO NOT set shrinkWrap: true or NeverScrollableScrollPhysics here —
  // let the Expanded parent provide bounded height so all page rows scroll.
  ...
)
```

**Required behavior:**

- Table body is **vertically scrollable** within the modal; all items on the current page (e.g. 12) are reachable by scroll.
- Pagination footer remains at the **bottom-left** of the table (default `AppListTable` placement) with `hrPageLabel` formatting.
- Sortable columns, loading/empty/error states match the staff directory.
- **No inline View/Edit/Assign buttons** on rows; row click opens the appropriate detail or edit dialog.
- Remove duplicate search field from the modal `Column` once `AppListTableSearch` is wired.

---

## 3. Staff Tab

### 3.1 Table columns

| Column | Source | Notes |
|--------|--------|-------|
| Staff | `displayLabel` + linked staff identifier | `_HrAccessCopyableIdentifierCell` / `_CopyableIdentifierCell` with staff number when linked |
| Email | `email` | Single line |
| Assigned roles | `roleNames` | Localize via `hrReferenceRoleLabel`; show "—" when empty, not "Not available" |
| Status | `status` | `AppStatusText` with `hrAccessUserStatusTone` |
| Position | `positionTitle` | Optional; hide column when empty for all rows |

### 3.2 Staff detail dialog

**Fix the `limit` validation bug first** — ensure all HR access repository calls respect `MAX_PAGE_LIMIT` (100). For role/permission lists that may exceed 100, paginate or batch requests.

Row click → `showHrAccessUserDetailDialog`. The dialog must render `_HrAccessUserDetailContent` with:

- Display name / profile name (title of dialog)
- Email, phone, position, status
- Linked staff profile (name + staff number, with **Open staff profile** action)
- Assigned roles (chips)
- Direct permissions (chips)
- **Edit staff account** → `showHrEditAccessUserDialog` (reuse `AppRoleAssignmentPicker` + new permission picker)

If detail load fails, show `AppFailureStateView` with retry — not a generic "Check the details" shell with no content.

### 3.3 Footer

- **Create staff** → `showHrStaffOnboardingDialog` (canonical staff + account creation).
- **Refresh** → `_reload(resetPage: true)`.

---

## 4. Roles Tab

### 4.1 Table columns

| Column | Source | Notes |
|--------|--------|-------|
| Role name | `name` | Localized via `hrReferenceRoleLabel` |
| Description | `description` | Ellipsis truncate |
| Permissions | `permissionCount` | `hrAccessPermissionCountLabel` |
| Staff | `userCount` | `hrAccessStaffAssignmentCountLabel` |
| System | `isSystemCritical` | Chip when true; em dash when false |

Ensure list API maps `permission_count` and `user_count` from backend DTOs so rows do not show placeholder "No permissions" / "No staff" when data exists.

### 4.2 Role detail dialog

Row click → `showHrAccessRoleDetailDialog` (existing). Keep **Assign permissions** and **Edit role** in dialog actions. After mutation, call `onChanged` to refresh the roles table without closing Staff access modal.

### 4.3 Assign permissions flow

Refactor `showHrAssignRolePermissionsDialog` to:

1. Load **all** tenant permissions (use `pageSize: 100` and paginate if `totalItemCount > 100`, or a dedicated `listAllAccessPermissions` helper).
2. Use the new **`AppPermissionAssignmentPicker`** (see §6) instead of inline checkbox list.
3. Pre-select permissions already on the role via `listRolePermissionOptions` (fix `limit: 200` → `100` or paginate).

---

## 5. Permissions Tab

### 5.1 Table columns

| Column | Source | Notes |
|--------|--------|-------|
| Permission name | `name` | e.g. `reports:write` |
| Description | `description` | Fallback to generated label |
| Roles | `roleCount` | `hrAccessPermissionRoleCount` |

### 5.2 Permission catalog (create & edit)

**Do not allow free-text permission names.** Source of truth for selectable permissions:

```dart
AppPermissions.all // from access_policy.dart
```

Refactor `showHrCreatePermissionDialog` and `showHrEditPermissionDialog`:

| Field | Control |
|-------|---------|
| Permission name | `AppSelectField.searchable` (or dedicated searchable select) populated from `AppPermissions.all`, displaying `permission.code` and a human-readable description from l10n or a static map |
| Description | Optional `AppTextField`; pre-fill from catalog default when a permission is selected |

On create, POST only permissions from the catalog that are not yet provisioned for the tenant (or upsert if backend supports it). On edit, lock the permission name (read-only) — only description is editable.

### 5.3 Row click

- Read-only users → `showHrAccessPermissionDetailDialog`
- Writers → `showHrEditPermissionDialog`

---

## 6. Reusable Components

Extract and use consistently (HR modal today; access-admin `/settings` later per [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md)):

| Component | Responsibility | Based on |
|-----------|----------------|----------|
| `AppRoleAssignmentPicker` | Searchable multi-select roles with effective-permissions preview | Existing `app_role_assignment_picker.dart` |
| `AppPermissionAssignmentPicker` (**new**) | Searchable multi-select from `AppPermissions.all` + tenant-provisioned permissions; select-all / clear; optional grouping by module prefix (`hr:`, `roster:`, etc.) | Mirror `AppRoleAssignmentPicker` API |
| `AppAccessEntityTable<T>` (**optional thin wrapper**) | Standard `AppListTable` + `AppListTableSearch` + pagination wiring for access entities | Staff directory pattern |

Replace inline permission checkbox blocks in `showHrEditAccessUserDialog` and `showHrAssignRolePermissionsDialog` with `AppPermissionAssignmentPicker`.

---

## 7. API & Sync Fixes

### 7.1 Fix invalid `limit` values

In `hr_repository_impl.dart`, replace hard-coded `limit: 200` with `limit: 100` (or `AppPageRequest.maxPageSize` constant aligned to backend `MAX_PAGE_LIMIT`). Affected methods include at minimum:

- `listUserRoles` (line ~687)
- `listRolePermissions` / `listRolePermissionOptions` (line ~615)

Add pagination loops where result sets can exceed 100.

### 7.2 Load full permission sets for pickers

When dialogs need the full permission list, pass explicit `pageRequest: const AppPageRequest(pageSize: 100)` and fetch subsequent pages until `hasNextPage` is false — do not rely on default `pageSize: 12`.

### 7.3 Realtime refresh

After create/edit/assign/revoke mutations:

1. Call `_reload(resetPage: true)` on the active Staff access panel.
2. If a detail dialog is open for the mutated entity, re-fetch and update its content (or close and reopen with fresh data).
3. Subscribe to relevant `RealtimeEventGroups` for users/roles/permissions if not already wired in `HrWorkspaceController` — refresh rows when backend emits changes from another session.

---

## 8. Terminology (l10n)

Update `app_en.arb` (regenerate localizations):

| Key / current string | New string |
|----------------------|------------|
| `hrAccessPanelUsers` | **Staff** |
| `hrCreateUserAction` | **Create staff** |
| `hrAccessEmptyUsersLabel` | Reword to "staff" |
| `hrAccessSearchHint` | Align with staff directory search hint pattern |
| New keys for permission catalog labels | Human-readable names for each `AppPermissions` entry used in searchable select |

Do **not** rename domain types (`HrAccessUser`, API fields); only user-visible labels.

---

## 9. Out of Scope

Defer to future prompts:

- Full access-admin workspace at `/settings`
- Permission matrix bulk editor, demo account management, break-glass access
- Advanced filters (department, role multi-select) on staff access tables
- Backend schema changes (unless required to fix count aggregates)
- Audit log of permission changes

---

## Acceptance Criteria

- [ ] Staff access modal opens **maximized**, is **resizable**, and table body **scrolls** to show all rows on the current page (12 visible via scroll, not 5).
- [ ] All three panels use **`AppListTable` + `AppListTableSearch`** with column settings — no duplicate standalone search field.
- [ ] Panel tabs are **square-edged** with no checkmark icon; labels read **Staff / Roles / Permissions**.
- [ ] Clicking a staff row opens a **populated detail dialog** (name, email, roles, etc.) — no **"Invalid value for limit"** error.
- [ ] All repository `limit` params respect backend max (**≤ 100**); paginated fetches where needed.
- [ ] **Create permission** uses searchable select from **`AppPermissions.all`**, not a free-text name field.
- [ ] **`AppPermissionAssignmentPicker`** is used in role-assign and user-edit flows; loads **all** tenant permissions.
- [ ] **`AppRoleAssignmentPicker`** is used in user-edit / onboarding role assignment (not ad-hoc checkbox lists).
- [ ] Staff table shows **assigned role names** when available; aggregates on roles/permissions tabs reflect backend counts.
- [ ] After any mutation, the active panel refreshes; detail dialogs reflect latest data.
- [ ] `flutter analyze` passes; new strings in `app_en.arb`.

---

## Implementation Notes

- Reference table layout: `_HrStaffDirectoryPanel` in `hr_workspace_page.dart` (~lines 430–560).
- Reference maximized dialog: `hr_staff_onboarding_dialog.dart` (`initialMaximized: true`).
- Reference square tabs: `AppWorkspaceBoardToggle` in `frontend/lib/shared/layout/app_workspace_board_toggle.dart`.
- Permission catalog: `AppPermissions` in `frontend/lib/core/permissions/access_policy.dart`.
- Backend limit validation: `backend/src/lib/validation/zod.js` (`MAX_PAGE_LIMIT = 100`).
- Existing dialogs to extend (do not duplicate): `showHrAccessUserDetailDialog`, `showHrEditAccessUserDialog`, `showHrAccessRoleDetailDialog`, `showHrEditRoleDialog`, `showHrAssignRolePermissionsDialog`, `showHrEditPermissionDialog`, `showHrCreatePermissionDialog`.

---

## Test Plan

1. Open `/hr` → ⋮ → **Manage users and roles** → verify modal is maximized.
2. **Staff tab:** scroll table — all 12 rows on page 1 reachable; pagination shows correct range; row click opens detail with name, email, roles.
3. **Create staff** — onboarding dialog opens without API errors.
4. **Roles tab:** counts display correctly; open role → assign permissions → save → table refreshes with updated permission count.
5. **Permissions tab:** create permission — only catalog entries selectable; edit locks name; role count updates after role assignment.
6. Resize modal to mobile width — list layout renders; search and pagination still work.
7. Run `flutter test test/features/hr/presentation/widgets/hr_access_dialogs_test.dart` and update/add cases for limit fix and picker refactor.
