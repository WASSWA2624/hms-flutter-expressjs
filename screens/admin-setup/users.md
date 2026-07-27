# Action inventory — `/admin/setup?section=users`

## User list

- **Create user**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when workspace `canWrite` is true and `showCreateAction` is enabled (default on this setup tab); enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `openAccessAdminCreateUserDialog` / `showUserMutationDialog` in **Create** mode with Organization + User details only (no Assigned roles / Direct permissions; those are managed from User Details). Fields stay visible and disable with tooltips until tenant/facility scope is ready.
  - Similarity review: Before persisting, the flow always runs a scored duplicate/similarity review (`_reviewUserSimilarity` → `showUserSimilarityDialog`) against tenant-scoped peers on email, phone, and position title. Same-tenant exact email or phone digits hard-block create; softer near matches surface for review and can be overridden with **Create anyway** (`confirm_similar`). **Use existing** opens that user's details instead of creating; **Cancel** dismisses. Backend uniqueness (`errors.user.similar_exists` / `errors.user.*_exists_in_tenant`) is authoritative and reopens the review hydrated from the 409 match payload.
  - Details handoff: On successful create (or **Use existing**), the users list is covered immediately and User Details opens for the resulting user (`_openUserDetail(item, coverListImmediately: true)`) with a silent background list refresh — no list flash. Roles and direct permissions are assigned afterward from User Details.

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

- **Activate / Deactivate user**
  - Location: Dialog footer / detail actions.
  - Condition: Shown when `canWrite` is true and the user is not soft-deleted; label is **Deactivate user** when status is `ACTIVE`, otherwise **Activate user**.
  - Immediate result: Toggles status via `setUserStatus`, then closes the details dialog on success.

- **Delete user**
  - Location: Dialog footer / detail actions.
  - Condition: Shown when `canWrite` is true, the user is not soft-deleted, and not demo/system-critical.
  - Immediate result: Soft-delete confirm flow (same as list Delete).

- **Add role**
  - Location: Assigned roles section header in `AppUserAccessPanel`.
  - Condition: Shown when `canWrite` is true and the user is not soft-deleted; disabled while a role/permission mutation is in progress.
  - Immediate result: Opens role assignment picker; on confirm assigns selected roles and reloads user detail (list silently refreshes).

- **Remove role**
  - Location: Each removable assigned-role card.
  - Condition: Shown when `canWrite` is true, the user is not soft-deleted, and the role assignment has a `userRoleId` and is not system-critical; disabled while busy.
  - Immediate result: Confirms then revokes the user-role link and reloads detail. Inherited permissions are display-only (collapsed by default; expand to view chips) and cannot be removed individually.

- **Add permission**
  - Location: Direct permissions section header.
  - Condition: Shown when `canWrite` is true and the user is not soft-deleted; disabled while busy.
  - Immediate result: Opens direct-permission picker; save syncs the direct grant set and reloads detail.

- **Remove permission**
  - Location: Each direct-permission row.
  - Condition: Shown when `canWrite` is true and the user is not soft-deleted; disabled while busy.
  - Immediate result: Syncs the remaining direct permission ids (role grants unaffected) and reloads detail.

- **Close**
  - Location: Dialog footer.
  - Condition: Always available.
  - Immediate result: Closes the details dialog.
