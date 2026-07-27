# Action inventory — `/admin/setup?section=roles`

## Role list

- **Create role**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when workspace `canWrite` is true and `showCreateAction` is enabled (default on this setup tab); enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `showRoleMutationDialog` in **Create** mode.

- **Row select**
  - Location: Role table or mobile-list row.
  - Condition: Always available for listed roles.
  - Immediate result: Loads the role’s permissions by UUID (`mutationId`), then opens `_AccessAdminRoleDetailDialog` (edit/delete hidden when the role is soft-deleted).

- **Edit**
  - Location: Role row actions (active roles only).
  - Condition: The actions column is shown when workspace `canWrite` is true; hidden for soft-deleted roles; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `showRoleMutationDialog` in **Edit** mode with the same RBAC/ABAC Scope radios as Create (**Platform** / **Tenant(s)** / **Facility(ies)**) plus Role details (no Permissions section), pre-filled from the role’s actual `tenant_id` / `facility_id`. Save runs similarity review excluding the edited role when identity or scope change. On success, opens role details for the edited role (same handoff as Create). Permissions stay managed from role details.

- **Delete**
  - Location: Role row actions (active roles only).
  - Condition: The actions column is shown when workspace `canWrite` is true; the delete control is shown only when the role is not system-critical and not already soft-deleted; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens soft-delete confirm; on confirm soft-deletes the role and marks the row deleted immediately (local mark is re-applied after silent refresh so stale reloads cannot resurrect Edit/Delete).

- **Restore**
  - Location: Role row actions (soft-deleted roles).
  - Condition: Shown when `canWrite` is true and the role is soft-deleted.
  - Immediate result: Confirms then restores the role plus matching soft-deleted permission and user-role links.

- **Delete permanently**
  - Location: Role row actions (soft-deleted roles).
  - Condition: Shown when `canWrite` is true, the role is soft-deleted, and not system-critical.
  - Immediate result: Opens type-to-confirm dialog; **Permanent delete** stays disabled until the typed text matches the role name (title / display name / Deleted label variants). On match + submit: hard-delete — scan all user_role attachments (active or soft-deleted), remove the role from those users, erase role permissions, then delete the role row.

- **Previous page**
  - Location: Role-list pagination controls.
  - Condition: Enabled when a previous page is available.
  - Immediate result: Loads the previous role page.

- **Next page**
  - Location: Role-list pagination controls.
  - Condition: Enabled when a next page is available.
  - Immediate result: Loads the next role page.

- **Retry**
  - Location: Role-list failure state.
  - Condition: Shown when loading the role list fails.
  - Immediate result: Reloads the first role page.

## Role details dialog

- **Add permissions / Edit permissions**
  - Location: When the role has permissions, top-right of the Permissions section header. When the role has none, centered in the Permissions empty state (with centered empty copy).
  - Condition: Shown when `canWrite` is true and the role is not soft-deleted; labeled **Add permissions** when the role has none, otherwise **Edit permissions**; disabled while a permission sync is in progress.
  - Immediate result: Opens the permission assignment dialog **maximized**; save syncs the role’s permission set (including clearing all grants) and refreshes the grouped list from a fresh API read (duplicates collapsed by permission id/code).

- **Edit role**
  - Location: Dialog footer.
  - Condition: Shown when `canWrite` is true and the role is not soft-deleted.
  - Immediate result: Closes details and opens the role edit mutation dialog.

- **Delete role**
  - Location: Dialog footer.
  - Condition: Shown when `canWrite` is true, the role is not soft-deleted, and not system-critical.
  - Immediate result: Soft-delete confirm flow (same as list Delete).

- **Close**
  - Location: Dialog footer.
  - Condition: Always available.
  - Immediate result: Closes the details dialog.
