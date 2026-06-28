# Task: HR Staff access modal — working Users, Roles, and Permissions management

## Goal

Make the **Staff access** modal (`/hr` → **Manage users and roles**) fully functional so HR administrators can manage user accounts, assign **multiple roles** per user, assign **direct permissions** (markup/overrides), and maintain roles and permissions — all from a simple, modal-first workflow without leaving the HR workspace.

**Prerequisite:** `AppDialog` resize and viewport maximize should work (see [prompt2.md](./prompt2.md) if not landed).

## Context

The modal shell already exists and matches the intended UX (segmented **Users / Roles / Permissions** tabs, search, refresh, and primary create actions). Entry points:

| Entry | Location |
| --- | --- |
| HR toolbar | `hr_workspace_page.dart` → `showHrAccessWorkspaceDialog` |
| Overflow menu | Same action via `hrManageAccessAction` / `manage_users_roles` |
| Staff detail | `hr_enhanced_dialogs.dart` → module access summary → **Manage users and roles** |

| Area | Current implementation |
| --- | --- |
| Dialog shell | `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart` — `_HrAccessWorkspaceDialog` |
| Data layer | `hr_repository_impl.dart` — `listAccessUsers/Roles/Permissions`, CRUD via Users/Roles/Permissions APIs |
| Controller | `hr_workspace_controller.dart` — `loadAccessUsers`, `assignUserRolesBatch`, `assignRolePermissionsBatch`, etc. |
| Peer reference | `frontend/lib/features/access_admin/` — full access-admin workspace with user detail, role/permission assignment patterns |
| Module boundary | [prompts/04-access-admin-module-prompt.md](./prompts/04-access-admin-module-prompt.md) — backend auth is source of truth; HR links staff to users and grants access in context |

Design references: `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`.

**Reference screenshots (current UI at `127.0.0.1:5201/hr`):**

- Overflow **⋯** menu → **Manage users and roles** opens **Staff access** modal (shell OK).
- **Users** tab shows generic error **"Check the details" / "Check the highlighted details."** instead of a user list — no actionable context.
- Footer actions (**Refresh**, **Create user account**) render but list area is broken.

## Problems (observed + code review)

### 1. Users tab fails to load — misleading validation error

Opening the modal triggers `loadAccessUsers` with a `tenant_id` query param. The backend `listUsersQuerySchema` requires `tenant_id` to be a **UUID**. `_tenantId()` in `hr_access_dialogs.dart` reads `HrStaffProfile.tenantId`, which is populated from `tenant_display_id` **before** `tenant_id` in `HrStaffProfileDto` — so a human-friendly tenant ID is sent to the API, validation fails, and `AppFailureStateView` shows the generic form-validation copy even though there is no form.

### 2. Users panel is list-only with minimal edit affordance

- Rows show name, email, roles, status, and a trailing **Edit user** button only.
- **Edit user** dialog (`showHrEditAccessUserDialog`) exposes **status** only — no email, roles, direct permissions, or linked staff profile.
- Clicking a user row does nothing; there is no detail/read view or nested edit flow.

### 3. Multi-role assignment is incomplete

- **Create user account** includes initial role checkboxes (good).
- **Edit user** cannot add, remove, or replace roles.
- No revoke-role action; batch assign exists in the controller but is not surfaced in edit UX.

### 4. Direct (markup) permissions not supported on users

Backend supports `user_permission` records. Access Admin create/update user drafts accept `permission_ids`. HR create/edit user flows do not expose direct permission pickers — only role-based access.

### 5. Roles panel — assign permissions starts empty

`showHrAssignRolePermissionsDialog` loads all permissions but does **not** pre-select permissions already linked to the role (`listRolePermissions` exists in repository but is unused). Saving only **adds** checked permissions; no revoke/sync of removed items.

### 6. Error and empty states are not HR-specific

Load failures use `errorValidationTitle` / `errorValidationMessage` (form-validation copy). Empty search results and permission-denied cases need distinct, actionable messages (e.g. retry, check tenant context, contact admin).

### 7. UX polish gaps

- Plain `ListTile` rows — no status badge, staff link, or row tap target.
- No pagination when user/role/permission count exceeds page size (default 12).
- Search fires on submit only; no debounced live filter.
- No permission gating on create/edit actions (Access Admin uses `canWrite` pattern).

## Requirements

### 1. Fix tenant context and list loading (blocker)

- Resolve **tenant UUID** for all Staff access API calls:
  - Prefer authenticated session tenant (`AuthSession.tenantId`) or HR workspace reference data tenant UUID.
  - Never pass `tenant_display_id` as `tenant_id` query/body param.
  - Fix `HrStaffProfileDto` mapping: store display ID separately; keep `tenantId` as backend UUID only (or add `tenantDisplayId` if UI needs it).
- If tenant context is unavailable, show an **empty state** with clear copy (mirror `accessAdminTenantContextRequiredTitle/Body`) — not a validation error.
- Map API failures to appropriate `AppFailure` categories so list errors show network/forbidden/not-found copy, not form-validation copy.

**Verify:** Users, Roles, and Permissions tabs each load demo-seeded data on `/hr` without error.

### 2. Users tab — browse, detail, and edit

Replace the flat list with an HR-appropriate worklist:

| Interaction | Behavior |
| --- | --- |
| Row tap / **View** | Open nested **User detail** dialog (`AppDialog` or `showAppWorkspaceMutationDialog` read-only section + edit actions) |
| Search | Filter by name, email, role name, status (debounced or submit — match Access Admin pattern) |
| Row content | Display name (or email), email, role chips, `AppStatusText` for account status, linked staff name/ID when `staffProfileId` present |
| **Create user account** | Keep existing flow; ensure role multi-select and tenant UUID fix |
| **Edit user** | Nested modal with: email (if API allows), phone, position title, status, **assigned roles** (multi-select checkboxes), **direct permissions** (multi-select checkboxes with search/grouping if list is long) |
| Staff link | When user has `staffProfileId`, show **Open staff profile** → closes access modal chain and opens HR staff detail for that profile |
| Save | Batch role assign via `assignUserRolesBatch`; sync direct permissions via user update `permission_ids` (add repository method if missing — follow Access Admin `AccessAdminUserDraft.permissionIds`) |
| Revoke role | Unchecking a role removes assignment (add `revokeUserRole` / batch revoke in controller if not wired from edit dialog) |

Reuse patterns from `access_admin_workspace_page.dart` (`_DetailContent`, role chips, effective permissions preview) where possible — extract shared widgets under `frontend/lib/shared/` only if duplication exceeds ~40 lines.

### 3. Roles tab — full CRUD and permission matrix

| Action | Behavior |
| --- | --- |
| List | Role name, description snippet, permission count, user count, system-critical badge |
| **Create role** | Existing dialog — verify tenant UUID |
| **Edit role** | Name + description; block edits when `isSystemCritical` |
| **Assign permissions** | Pre-load current role permissions via `listRolePermissions`; checkboxes reflect current state; save performs **sync** (assign new + revoke removed), not append-only |
| Delete role | Optional: add delete with confirmation when `userCount == 0` and not system-critical |

### 4. Permissions tab — maintain catalog

| Action | Behavior |
| --- | --- |
| List | Permission name, description, role usage count |
| **Create / Edit permission** | Existing dialogs — verify load/save |
| Search | Filter by name and description |

Direct user permission assignment lives on the **Users** edit flow (requirement 2), not here.

### 5. Keep the workflow simple

- **Modal-first:** Staff access → user detail → edit user = nested modals; no route navigation.
- **Minimal clicks:** Row tap opens detail; detail has **Edit** and **Manage roles & permissions** (or combined edit form).
- **Bulk-friendly:** Multi-select roles and permissions with **Select all / Clear** for long lists (reuse `AppCheckboxField` patterns from create-user flow).
- **Refresh:** Toolbar **Refresh** and post-mutation reload must update the active tab list and any open detail dialog.
- **Permissions:** Gate write actions with HR write + appropriate admin permissions (`AccessGate` / `AppAccessActionGate` — align with Access Admin `canWrite` checks).

### 6. Localization and tests

- Add any new strings to `app_en.arb` (user detail title, direct permissions label, tenant context required, role sync success, etc.).
- Add widget/controller tests:
  - `hr_access_dialogs` — loads users when tenant UUID resolved; shows tenant-required empty state when not.
  - Edit user — role multi-select saves via batch assign.
  - Assign role permissions — pre-selects existing permissions and syncs on save.
- Run from `frontend/`: `flutter analyze`, `flutter test test/features/hr/`.

## Architecture notes

- **Do not duplicate** Access Admin repository logic wholesale — extend `HrRepository` / controller only where HR modal needs thinner calls, or inject shared access helpers if both modules need the same sync logic.
- **Backend is source of truth** for effective permissions (roles + direct grants + entitlements). UI shows effective preview on user detail; editing changes assignments, not cached permission strings.
- **Coordinate APIs:** `GET/POST/PUT /users`, `GET/POST/PUT /roles`, `GET/POST/PUT /permissions`, `POST/DELETE /user-roles`, `POST/DELETE /role-permissions`, user update with `permission_ids`.
- Optional follow-up (out of scope below): **Open in Access Admin** deep-link from user detail for advanced matrix editing.

## Acceptance criteria

- [ ] `/hr` → **Manage users and roles** → **Users** tab lists demo users (no validation error).
- [ ] **Roles** and **Permissions** tabs load and search correctly.
- [ ] Clicking a user opens a detail view with identity, roles, effective permissions preview, and linked staff when present.
- [ ] Edit user supports **multiple roles** (add and remove) and **direct permissions** (add and remove).
- [ ] Create user account works with initial multi-role selection.
- [ ] Assign permissions on a role pre-loads current permissions and syncs changes on save.
- [ ] Tenant/display ID bug fixed — API always receives UUID for `tenant_id`.
- [ ] Errors and empty states use actionable, context-appropriate copy.
- [ ] `flutter analyze` and targeted HR tests pass.

## Test plan

1. Open `/hr` as demo HR admin → overflow → **Manage users and roles** → confirm user list renders.
2. Search for a demo user by email → row appears.
3. Tap user → detail dialog → verify roles and permissions preview.
4. Edit user → add second role, add one direct permission, save → reopen and confirm persistence.
5. Remove a role → save → confirm role revoked.
6. **Roles** tab → **Assign permissions** on a non-system role → confirm existing permissions pre-checked → uncheck one, check one new → save → verify sync.
7. **Permissions** tab → create permission → appears in list.
8. **Create user account** with two initial roles → user appears in list with both roles.
9. Regression: staff detail → module access → **Manage users and roles** still opens same modal.

## Out of scope

- Full Access Admin workspace features (demo account reset, module entitlements panel, break-glass).
- Rewiring unrelated HR toolbar items (work queues, schedule templates, staff detail layout — see [prompt2.md](./prompt2.md) and [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md)).
- Backend schema changes unless an existing API contract is broken for HR flows.
- Route-based `/access-admin` navigation from HR (optional deep-link only).
