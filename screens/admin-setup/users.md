# Action inventory — `/admin/setup?section=users`

## User list

- **Create user**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when workspace `canWrite` is true and `showCreateAction` is enabled (default on this setup tab); enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `openAccessAdminCreateUserDialog` / `showUserMutationDialog` in **Create** mode.

- **Row select**
  - Location: User table or mobile-list row.
  - Condition: Always available for listed users.
  - Immediate result: Loads user detail by UUID (`mutationId`), then opens `_AccessAdminUserDetailDialog` (edit/delete hidden when the user is soft-deleted).

- **Edit**
  - Location: User row actions (active users only).
  - Condition: The actions column is shown when workspace `canWrite` is true; hidden for soft-deleted users; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `openAccessAdminEditUserDialog` / `showUserMutationDialog` in **Edit** mode with the user’s detail preloaded.

- **Delete**
  - Location: User row actions (active users only).
  - Condition: Shown when `canWrite` is true and the user is not demo, not system-critical, and not soft-deleted; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens soft-delete confirm; on confirm soft-deletes the user and marks the row deleted (list silently refreshes).

- **Restore**
  - Location: User row actions (soft-deleted users).
  - Condition: Shown when `canWrite` is true and the user is soft-deleted.
  - Immediate result: Confirms then restores the user; list silently refreshes.

- **Filters**
  - Location: Search-bar advanced Filters control.
  - Condition: Role and status filters for all writers. Tenant filter only when `canCreateTenant()`. Facility filter when the actor can filter across facilities (`canCreateTenant()` or `canCreateTenantWideRole()`), and for platform admins only after a tenant is selected.
  - Immediate result: Reloads the first page with scoped `allTenants` / `allFacilities` / tenant / facility / role / status query params. Backend RBAC/ABAC remains authoritative for which rows appear.

- **Previous page / Next page / Retry**
  - Location: Shared list pagination and failure state.
  - Condition: Enabled when previous/next pages exist; Retry when load fails.
  - Immediate result: Loads the requested page or reloads the first page.

## User details dialog

- **Edit user**
  - Location: Dialog footer / detail actions.
  - Condition: Shown when `canWrite` is true and the user is not soft-deleted.
  - Immediate result: Closes details and opens the edit-user mutation dialog.

- **Delete user**
  - Location: Dialog footer / detail actions.
  - Condition: Shown when `canWrite` is true, the user is not soft-deleted, and not demo/system-critical.
  - Immediate result: Soft-delete confirm flow (same as list Delete).

- **Close**
  - Location: Dialog footer.
  - Condition: Always available.
  - Immediate result: Closes the details dialog.
