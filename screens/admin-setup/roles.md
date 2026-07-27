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
  - Immediate result: Opens `showRoleMutationDialog` in **Edit** mode (same form as create, plus permissions). Save runs similarity review excluding the edited role when identity fields change.

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
