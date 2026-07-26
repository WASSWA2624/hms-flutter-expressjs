# Action inventory — `/admin/setup?section=facility`

## Platform facility list

- **Add facility**
  - Location: Search-bar trailing action and empty-state primary action.
  - Condition: Shown when `canManageFacility()`; disabled while the list is loading.
  - Immediate result: Opens `_SetupProfileDialog` in **Create facility** mode.

- **Open facility details** (facility row)
  - Location: Active facility table or mobile-list row.
  - Condition: The facility must not be soft-deleted.
  - Immediate result: Opens `_FacilityDetailsDialog`.

- **Edit**
  - Location: Active facility row actions.
  - Condition: The actions column is shown when `canManageFacility()`; disabled while loading.
  - Immediate result: Opens `_SetupProfileDialog` in **Edit facility** mode.

- **Delete**
  - Location: Active facility row actions.
  - Condition: Shown when `canManageFacility()`; disabled while loading.
  - Immediate result: Opens the soft-delete facility `AppConfirmActionDialog`.

- **Restore**
  - Location: Soft-deleted facility row actions.
  - Condition: Shown when `canManageFacility()`; disabled while loading.
  - Immediate result: Opens the restore facility `AppConfirmActionDialog`.

- **Permanent delete**
  - Location: Soft-deleted facility row actions.
  - Condition: Shown when `canManageFacility()`; disabled while loading.
  - Immediate result: Opens the permanent-delete `AppTextInputActionDialog`.

- **Previous page**
  - Location: Facility-list pagination controls.
  - Condition: Enabled when a previous page is available.
  - Immediate result: Loads the previous facility page.

- **Next page**
  - Location: Facility-list pagination controls.
  - Condition: Enabled when a next page is available.
  - Immediate result: Loads the next facility page.

- **Retry**
  - Location: Facility-list failure state.
  - Condition: Shown when loading the facility list fails.
  - Immediate result: Reloads the first facility page.
