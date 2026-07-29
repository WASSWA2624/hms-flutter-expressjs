# Action inventory — `/admin/access`

Primary surface: `AccessAdminWorkspacePage` (`frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`).

Write gate: workspace `canWrite` from backend permissions. Registrations tab only for elevated (super-admin) actors. Unauthorized create / next-action / destructive controls do not render.

Dialog chrome: each `AppDialog` has an icon-only **Close** that only dismisses; noted once here.

---

## Task inventory — duplicates / redundant surfaces

| Duplicate / redundant surface | Outcome | Merge / removal |
| --- | --- | --- |
| Tab **Overview** (same users worklist as Directory; no overview UI) | Browse users | **Removed** — deep links `panel=overview` coerce to Directory |
| Tab-strip **Refresh** | Reload worklist | **Removed** — scaffold **Try again**, mutation refresh, and realtime sync remain |
| Inline create-user dialog on this page | Create user | **Merged** into shared `openAccessAdminCreateUserDialog` (scope, validation, similarity) |
| Extra `refresh()` after create-role dialog | Sync list | **Removed** — `createRole` already refreshes the worklist |
| Detail **Edit role** vs row **Edit role** next-action | Edit role | **Removed** from detail — row next-action is the sole edit entry |
| Detail **Activate / Deactivate** vs row status next-action | Toggle user status | **Removed** from detail — row next-action is the sole status entry |
| Detail **Activate registration** vs row next-action | Activate registration | **Removed** from detail — row next-action is the sole activate entry; **Reject** stays on detail |
| Mobile list without next-action trailing (after detail merge) | Status / edit / activate | **Fixed** — `accessAdminMobileNextAction` on `AppListTableMobileItem.trailing` mirrors desktop `next_action` |
| Post-edit **role detail auto-reopen** | View role after edit | **Removed** — edit ends on the synced worklist; open detail via row select when needed |

---

## Access admin workspace screen

### Tab strip

- **Directory / Roles / Permissions / Entitlements / Registrations / Demo**
  - Location: Page chrome `AppTabStrip`.
  - Opens modal: No.
  - Immediate result: Switches panel/resource, updates URL `?panel=…`.
  - Condition: **Registrations** only when `appAccessPolicy.isElevated`. **Overview** absent.

- **Create user** (primary)
  - Location: Tab-strip primary when resource is users or demo users.
  - Opens modal: Yes — shared create-user mutation + similarity review.
  - Immediate result: Creates user (or uses existing via similarity); worklist syncs.
  - Condition: `canWrite` and tenant context available (registrations exempt from tenant gate).

- **Create role** (primary)
  - Location: Tab-strip primary when resource is roles.
  - Opens modal: Yes — shared create-role mutation + similarity review.
  - Immediate result: Creates role; worklist syncs.
  - Condition: `canWrite` and tenant context available.

Tab-strip **Refresh** and **Overview** were removed. Worklist data refreshes after mutations via the workspace controller; load failures use scaffold **Try again**.

- **Try again** (page load / failure banner)
  - Location: `AsyncStateScaffold` or `AppFailureStateView`.
  - Opens modal: No.
  - Immediate result: Reloads workspace.
  - Condition: Load or mutation failure.

### Search / filters / table chrome

- **Search**, **Filters** (advanced), **Settings** (columns), **Previous / Next page**
  - Location: `AppListTable` / `AppSearchBar` chrome.
  - Opens modal: Advanced filters panel; Table Settings dialog.
  - Immediate result: Filters/search/columns/pagination for the active resource.
  - Condition: Status filter on users/demo; role-scope filter on roles.

### Empty / no-results

- **Empty worklist**
  - Location: `AppStateView` when the page has no items and is not refreshing.
  - Opens modal: No.
  - Immediate result: Shows empty copy; create remains on the tab-strip primary when authorized.
  - Condition: Empty page.

### Row activation

- **Row select** (desktop row / mobile item)
  - Location: Table row / mobile list item.
  - Opens modal: Item detail dialog (read-focused).
  - Immediate result: Loads user detail or role permissions when needed, then opens detail.
  - Condition: Always when rows exist.

### Users / demo users

- **Activate / Deactivate** (next-action)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing` via `accessAdminMobileNextAction`.
  - Opens modal: No.
  - Immediate result: Toggles `ACTIVE` / `INACTIVE` via `setUserStatus`.
  - Condition: `canWrite`.

### Directory tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Directory tab | navigate | read ∪ `tenant:admin` \| `facility:admin` \| `system:admin` |
| Search / filters / columns / pagination | read chrome | read ∪ |
| Empty / error / retry | read chrome | read ∪ |
| Row select → user detail | read | read ∪ |
| Create user (tab primary) | create | write ∩ `tenant:admin` + workspace `canWrite` |
| Activate / Deactivate (next-action / mobile trailing) | update | write ∩ + `canWrite` |
| Delete | delete | write ∩ (matrix; no delete UI on Directory today) |
| Open HR profile | navigate | linked `staffProfileId` (nested cross-module n/a) |
| Detail Close | progressive-disclosure | read ∪ |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminDirectoryAtomPermissions`, `canReadAccessAdminDirectory`, `canMutateAccessAdminDirectory`. Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) via `canWriteAccessAdmin`. Assignable rights stay within actor ceiling / subscription (backend authoritative).

### Demo tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Demo tab | navigate | read ∪ `tenant:admin` \| `facility:admin` \| `system:admin` |
| Search / filters / columns / pagination | read chrome | read ∪ |
| Empty / error / retry | read chrome | read ∪ |
| Row select → demo user detail | read | read ∪ |
| Create user (tab primary) | create | write ∩ `tenant:admin` + workspace `canWrite` |
| Activate / Deactivate (next-action / mobile trailing) | update | write ∩ + `canWrite` |
| Reset demo password (detail) | update | write ∩ + `canWrite` + workspace `canResetDemoPasswords` |
| Delete | delete | write ∩ (matrix; no delete UI on Demo today) |
| Open HR profile | navigate | linked `staffProfileId` (nested cross-module n/a) |
| Detail Close | progressive-disclosure | read ∪ |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminDemoAtomPermissions`, `canReadAccessAdminDemo`, `canWriteAccessAdmin`, `canResetDemoPasswordAccessAdmin`. Same write gate as Directory. Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) via `canWriteAccessAdmin`.

### Roles

- **Edit role** (next-action)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing` via `accessAdminMobileNextAction`.
  - Opens modal: Yes — shared edit-role dialog.
  - Immediate result: Updates role identity/scope; worklist syncs (no auto detail reopen).
  - Condition: `canWrite` and role is not system-critical.

### Roles tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Roles tab | navigate / progressive-disclosure | read ∪ `tenant:admin` \| `facility:admin` \| `system:admin` |
| Search / filters / columns / pagination | read chrome | read ∪ |
| Empty / error / retry | read chrome | read ∪ |
| Row select → role detail | read | read ∪ |
| Create role (tab primary) | create | write ∩ `tenant:admin` + workspace `canWrite` |
| Edit role (next-action / mobile trailing) | update | write ∩ + `canWrite`; not system-critical |
| Delete role (detail footer + confirm) | delete | write ∩ + `canWrite`; not system-critical |
| Detail Close | progressive-disclosure | read ∪ |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminRolesAtomPermissions`, `canReadAccessAdminRoles`, `canMutateAccessAdminRoles`. Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) via `canWriteAccessAdmin` / `canMutateAccessAdminRoles`. Workspace Roles panel write chrome uses `canMutateAccessAdminRoles`. Assignable rights stay within actor ceiling / subscription (backend authoritative).

### Registrations

- **Activate registration** (next-action)
  - Location: `next_action` column; mobile `AppListTableMobileItem.trailing` via `accessAdminMobileNextAction`.
  - Opens modal: No.
  - Immediate result: Activates the registration follow-up.
  - Condition: elevated tab + write ∩ `tenant:admin` + workspace `canWrite` (`canMutateAccessAdminRegistrations`).

### Registrations tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Registrations tab | navigate | elevated (source); matrix ∩ `system:admin` |
| Search / filters / columns / pagination | read chrome | elevated |
| Empty / error / retry | read chrome | elevated |
| Row select → registration detail | read | elevated |
| Activate registration (next-action / mobile trailing) | update | elevated + write ∩ `tenant:admin` + workspace `canWrite` |
| Reject registration (detail) | delete | elevated + write ∩ + `canWrite` |
| Create user / Create role primary | create | _(absent on this resource)_ ; reserved write ∩ if added |
| Detail Close | progressive-disclosure | elevated |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminRegistrationsAtomPermissions`, `canReadAccessAdminRegistrations`, `canMutateAccessAdminRegistrations`, `canAccessAccessAdminRegistrations`. Workspace route entry remains read ∪ (`tenant:admin` \| `facility:admin` \| `system:admin`); this tab is stricter (elevated-only). Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) via `canWriteAccessAdmin` plus the elevated tab gate. Prompt ∩ `system:admin` maps to `accessAdminRegistrationsReadRequirement`; runtime tab gate prefers elevated (`SUPER_ADMIN`) so bare `system:admin` without elevation does not unlock the panel. Assignable rights stay within actor ceiling / subscription (backend authoritative).

### Detail dialog (shared)

- **Close**
  - Location: Dialog footer.
  - Opens modal: No (closes detail).
  - Immediate result: Dismisses detail.

#### Role detail

- **Delete role**
  - Location: Dialog footer.
  - Opens modal: Soft-delete confirm.
  - Immediate result: Soft-deletes the role when confirmed.
  - Condition: `canWrite` and not system-critical.

#### User / demo detail

- **Reset demo password**
  - Location: Detail body actions.
  - Opens modal: No.
  - Immediate result: Resets demo password.
  - Condition: `canWrite`, item is demo, and `canResetDemoPasswords`.

- **Open HR profile**
  - Location: Detail body when `staffProfileId` is set.
  - Opens modal: No.
  - Immediate result: Navigates to `/hr`.
  - Condition: Linked staff profile present.

#### Registration detail

- **Reject registration**
  - Location: Detail body actions.
  - Opens modal: No.
  - Immediate result: Rejects the registration follow-up.
  - Condition: elevated tab + write ∩ `tenant:admin` + workspace `canWrite` (`canMutateAccessAdminRegistrations`). Activate stays on the list next-action only.

Permissions and entitlements details are read-only summaries (no write next-actions on those resources).

### Entitlements tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Entitlements tab | navigate | read ∪ `tenant:admin` \| `facility:admin` \| `system:admin` |
| Search / filters / columns / pagination | read chrome | read ∪ |
| Empty / error / retry | read chrome | read ∪ |
| Row select → module entitlement detail | read | read ∪ |
| Detail Close | progressive-disclosure | read ∪ |
| Create / update / delete / next-action / tab primary | write | _(absent)_ ; reserved write ∩ `tenant:admin` + workspace `canWrite` |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminEntitlementsAtomPermissions`, `canReadAccessAdminEntitlements`, `canMutateAccessAdminEntitlements`. Catalog is read-only on this tab; workspace forces write chrome off for the Entitlements panel. Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) remains on the reserved mutate helper via `canWriteAccessAdmin`. Assignable / subscription module rights stay within actor ceiling (backend authoritative).

### Permissions tab atoms (matrix)

| Atom | Kind | Gate |
| --- | --- | --- |
| Permissions tab | navigate | read ∪ `tenant:admin` \| `facility:admin` \| `system:admin` |
| Search / columns / pagination | read chrome | read ∪ |
| Empty / error / retry | read chrome | read ∪ |
| Row select → catalog detail | read | read ∪ |
| Detail Close | progressive-disclosure | read ∪ |
| Create / update / delete / next-action / tab primary | write | _(absent)_ ; reserved write ∩ `tenant:admin` + workspace `canWrite` |
| Nested cross-module | — | _(n/a)_ |

Helpers: `AccessAdminPermissionsAtomPermissions`, `canReadAccessAdminPermissions`, `canMutateAccessAdminPermissions`. Catalog is read-only on this tab; workspace forces write chrome off for the Permissions panel. Source inventory write chrome maps to workspace `canWrite`; matrix ∩ `tenant:admin` (and elevated writers) remains on the reserved mutate helper via `canWriteAccessAdmin`. Prompt “edits elevated only” maps to that reserved path (no create/update/delete UI mounted today).

---

## Manual checks (Req 7)

- **Duplicates gone**: Overview and Refresh absent from the tab strip on desktop/mobile and light/dark; detail has no Activate/Deactivate, Edit role, or Activate registration; Edit role does not auto-reopen detail.
- **Merged entry points**: Create user uses the shared mutation dialog (tenant/facility scope + similarity); Create role / Edit role use shared role dialogs.
- **Authorized minimal paths**: With `canWrite`, Create user/role appear as tab primary; status / edit / activate appear as row next-actions (desktop column + mobile trailing) only; Delete role and Reject registration remain on detail; Edit role returns to the worklist.
- **Unauthorized**: With `canWrite` false, primary create and next-action cells/trailing are absent; Registrations tab absent when not elevated; Permissions / Entitlements catalogs never mount create / next-action / delete even for tenant writers.
- **States**: Loading/error use scaffold retry; empty uses empty state; validation/similarity live in shared mutation dialogs; success syncs the worklist without a toolbar Refresh.

Automated: `frontend/test/features/access_admin/presentation/access_admin_workspace_ux_simplify_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_roles_permissions_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_demo_permissions_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_directory_permissions_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_permissions_permissions_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_entitlements_permissions_test.dart`, `frontend/test/features/access_admin/presentation/access_admin_registrations_permissions_test.dart`.
