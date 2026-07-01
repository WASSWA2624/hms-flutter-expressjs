# HR Staff Access Dialog — Table Layout & UX Refinement

## Objective

Refine the **Staff access** modal in the HR workspace (`/hr`) so it matches the rest of the app's management-table patterns. Replace flat list rows with sortable `AppListTable` views, use row-click navigation into existing detail/edit dialogs, square off the panel tabs, and open the modal **maximized and resizable** by default.

**Entry point:** HR workspace → More actions (⋮) → **Manage users and roles** → `Staff access` modal.

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md), [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md)

**Primary touchpoints:**

| Area | File |
|------|------|
| Staff access modal (tabs, lists, actions) | `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart` |
| More-actions menu entry | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` |
| Staff directory table reference | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` (`AppListTable<HrStaffProfile>`) |
| Staff onboarding / create flow | `frontend/lib/features/hr/presentation/widgets/hr_staff_onboarding_dialog.dart` |
| Access entities | `frontend/lib/features/hr/domain/entities/hr_entities.dart` (`HrAccessUser`, `HrAccessRole`, `HrAccessPermission`) |
| Strings | `frontend/lib/l10n/app_en.arb` |

---

## Problem Statement (from current UI)

The Staff access modal is functionally present but visually and behaviorally inconsistent with the HR staff directory and other admin workspaces:

1. **Rounded segmented tabs** — `SegmentedButton` renders pill-shaped segments with checkmark icons. Tabs should be square-edged and align with workspace board-toggle styling (`AppWorkspaceBoardToggle` / `showSelectedIcon: false`).
2. **Flat list rows instead of tables** — Users, roles, and permissions render as stacked `ListTile` / custom row widgets with trailing **View** / **Edit** buttons. The HR staff directory already uses `AppListTable` with sortable columns, pagination, and row selection.
3. **Redundant inline actions** — Users show duplicate email lines, an **ACTIVE** badge, and separate **View** / **Edit user** links. Row click should be the primary affordance; detail and edit live in nested dialogs.
4. **Modal sizing** — Dialog opens at `maxWidth: 920`, not maximized. It should open **maximized by default** (`initialMaximized: true`) and remain **resizable** (`resizable: true`).
5. **Terminology** — The **Users** tab and **Create user account** action use generic "user" language. In HR context, these are facility **staff** accounts.
6. **Create action wiring** — Footer **Create user account** already opens `showHrStaffOnboardingDialog`; label should reflect staff creation, not a separate user-only flow.

---

## Global Standards

Follow the same rules as the HR module prompt:

- Hospital workflow language — show names, staff numbers, role labels, and status badges; never raw UUIDs in primary UI.
- Modal-first: all create/edit/detail flows use `AppDialog` / `showAppWorkspaceMutationDialog`.
- Reuse `frontend/lib/shared/*` components; follow `frontend/.cursor/design-system.mdc` and `ui-patterns.mdc`.
- Match the **HR staff directory** table patterns (`AppListTable`, `_CopyableIdentifierCell`, `_TwoLineCell`, `AppStatusText`, pagination labels).
- All new/changed strings in `frontend/lib/l10n/app_en.arb`.
- Permission-gate write actions with `canWriteHrAccess(ref)`; respect `hrWrite` permission.
- Refresh the active panel after every mutation via existing `_reload(resetPage: true)`.

---

## 1. Modal Shell

### 1.1 Maximized, resizable dialog

Update `_HrAccessWorkspaceDialog` `AppDialog` configuration:

| Property | Required value |
|----------|----------------|
| `initialMaximized` | `true` |
| `resizable` | `true` (default; keep enabled) |
| `showMaximizeButton` | `true` (allow restore after maximize) |
| `scrollable` | `true` |
| `maxWidth` | Remove or raise — when not maximized, use a sensible desktop width; maximized state should fill the viewport |

Remove `mainAxisSize: MainAxisSize.min` from content where it prevents the table from expanding; let the table fill available dialog height.

### 1.2 Square panel tabs

Replace the current `SegmentedButton<HrAccessPanel>` with square-edged tab styling:

- Use `AppWorkspaceBoardToggle<HrAccessPanel>` **or** `SegmentedButton` with `showSelectedIcon: false` and minimal/small border radius (match `AppWorkspaceBoardToggle` — `theme.radius.sm`, not pill-shaped).
- No checkmark icon on the selected tab.
- Rename tab labels (see §5 Terminology).

---

## 2. Staff Tab (formerly Users)

### 2.1 Replace list with `AppListTable<HrAccessUser>`

Remove `_HrAccessUserRow` and the `Column` of row widgets. Render staff accounts in `AppListTable` following the staff directory pattern in `hr_workspace_page.dart`.

**Suggested columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Staff | `displayLabel` + `staffProfileName` or `profileName` | Use `_CopyableIdentifierCell` with staff number / `displayId` when linked |
| Email | `email` | Single line; do not duplicate display label |
| Roles | `roleNames` | Comma-separated or chip summary; localize via `hrReferenceRoleLabel` |
| Status | `status` | `AppStatusText` with `hrAccessUserStatusTone` |
| Position | `positionTitle` | Optional column; hide when empty for all rows |

**Table behavior:**

- Server-side search via existing `_searchController` debounce and `HrAccessQuery` (keep search field above the table or integrate as `AppListTableSearch` if it fits without duplicating the search box).
- Pagination via `AppPageRequest` — replace manual "load more" with `AppListTable` `onPageChanged` / `pageLabelBuilder` using existing `hrPageLabel` l10n keys.
- `onRowSelected` → `showHrAccessUserDetailDialog(context, ref, user, onChanged: …)` — **do not** render trailing View/Edit buttons on rows.
- Empty state: keep `hrAccessEmptyUsersLabel` inside `emptyBuilder`.

### 2.2 Reuse existing detail & edit dialogs

- **Row click** opens `showHrAccessUserDetailDialog` (already loads `HrAccessUserDetail` and shows roles, direct permissions, linked staff profile).
- **Edit** remains available inside the detail dialog's **Edit user** action → `showHrEditAccessUserDialog`.
- Do not build a new user-detail view; extend `_HrAccessUserDetailContent` only if columns expose fields not yet shown.

### 2.3 Footer create action

- Rename **Create user account** → **Create staff** (or **Add staff account** — pick one consistent with `hrAddStaffAction` if it exists).
- Keep `onPressed` → `showHrStaffOnboardingDialog` (canonical staff + account creation flow).

---

## 3. Roles Tab

### 3.1 Replace list with `AppListTable<HrAccessRole>`

Remove per-row trailing **Edit role** / **Assign permissions** buttons from the list.

**Suggested columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Role | `name` (localized) | Primary identifier |
| Description | `description` | Truncate with ellipsis in cell |
| Permissions | `permissionCount` | e.g. "3 permissions" via `hrAccessRoleSummary` fragment |
| Assignments | `userCount` | e.g. "2 staff" |
| System | `isSystemCritical` | Badge/chip when true (`hrAccessSystemCriticalRoleBadge`); disable edit affordances for critical roles in detail only |

**Row click behavior:**

- Open existing `showHrEditRoleDialog` for editable roles, **or** a read-only role detail summary dialog if edit is not appropriate.
- **Assign permissions** moves to the role detail/edit flow (`showHrAssignRolePermissionsDialog`) — not inline on the table row.

### 3.2 Footer

- Keep **Create role** → `showHrCreateRoleDialog`.
- Keep **Refresh**.

---

## 4. Permissions Tab

### 4.1 Replace list with `AppListTable<HrAccessPermission>`

**Suggested columns:**

| Column | Source | Notes |
|--------|--------|-------|
| Permission | `name` | e.g. `unit:read` |
| Description | `description` | Fallback to generated label when null |
| Roles | `roleCount` | Via `hrAccessPermissionRoleCount` |

**Row click** → `showHrEditPermissionDialog`.

Remove trailing **Edit permission** button from rows.

### 4.2 Footer

- Keep **Create permission** → `showHrCreatePermissionDialog`.
- Keep **Refresh**.

---

## 5. Terminology (l10n)

Update `app_en.arb` (and regenerate localizations):

| Current key / string | New string |
|----------------------|------------|
| `hrAccessPanelUsers` → "Users" | **Staff** |
| `hrCreateUserAction` → "Create user account" | **Create staff** (or align with existing add-staff wording) |
| `hrAccessEmptyUsersLabel` | Reword to "staff" where user-facing |
| `hrAccessViewUserAction` | Remove from table UI (key may remain for detail dialog if used) |
| `hrAccessEditUserAction` | Keep for detail dialog only |

Do **not** rename domain types (`HrAccessUser`, API fields); only user-visible labels.

---

## 6. Out of Scope (implement later)

Defer to future prompts — do not block this refinement:

- Full access-admin workspace at `/settings` ([prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md))
- Permission matrix bulk editor, demo account management, break-glass access
- Advanced filters on staff access tables (department, role multi-select)
- Backend schema or API changes
- Audit log of permission changes
- Module entitlements editor inside this modal

---

## Acceptance Criteria

- [ ] Staff access modal opens **maximized** and can be **resized/restored** via the maximize control.
- [ ] Panel tabs (Staff / Roles / Permissions) have **square edges**, no selected checkmark icon.
- [ ] All three panels use **`AppListTable`** with sortable columns, pagination, and empty/loading states consistent with the HR staff directory.
- [ ] **No inline View/Edit/Assign buttons** on table rows; row click opens the appropriate existing detail or edit dialog.
- [ ] Staff tab shows name, email, roles, and status in table columns — not duplicate email lines.
- [ ] **Create staff** footer action opens `showHrStaffOnboardingDialog`.
- [ ] Tab label reads **Staff**, not Users; other user-facing copy uses "staff" where appropriate.
- [ ] `flutter analyze` passes; new strings localized in `app_en.arb`.
- [ ] After any mutation (create, edit, assign), the active panel refreshes without closing the modal.

---

## Implementation Notes

- Reference implementation for table layout: `_HrStaffDirectoryPanel` in `hr_workspace_page.dart` (~lines 426–560).
- Reference for maximized onboarding dialog: `hr_staff_onboarding_dialog.dart` (`initialMaximized: true`).
- Reference for square tabs: `AppWorkspaceBoardToggle` in `frontend/lib/shared/layout/app_workspace_board_toggle.dart`.
- Existing dialogs to reuse (do not duplicate): `showHrAccessUserDetailDialog`, `showHrEditAccessUserDialog`, `showHrEditRoleDialog`, `showHrAssignRolePermissionsDialog`, `showHrEditPermissionDialog`, `showHrCreateRoleDialog`, `showHrCreatePermissionDialog`.
