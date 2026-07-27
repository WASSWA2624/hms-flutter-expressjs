# Action inventory — `/admin/setup?section=roles`

## Role list

- **Create role**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when workspace `canWrite` is true and `showCreateAction` is enabled (default on this setup tab); enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `showRoleMutationDialog` in **Create** mode.

- **Row select**
  - Location: Role table or mobile-list row.
  - Condition: Always available for listed roles.
  - Immediate result: Loads the role’s permissions, then opens `_AccessAdminRoleDetailDialog`.

- **Edit**
  - Location: Role row actions.
  - Condition: The actions column is shown when workspace `canWrite` is true; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens `showRoleMutationDialog` in **Edit** mode.

- **Delete**
  - Location: Role row actions.
  - Condition: The actions column is shown when workspace `canWrite` is true; the delete control is shown only when the role is not system-critical; enabled when the list is not loading and no mutation is in progress.
  - Immediate result: Opens the delete role `AppConfirmActionDialog`.

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
