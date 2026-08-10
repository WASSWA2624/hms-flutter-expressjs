There is good progress. On the **HR Staff Details** dialog, we currently have an **Assign Position** button. This button should be used to assign a position to the selected staff member.

### Assign Position Flow

When **Assign Position** is clicked, open the **Assign Position** dialog. Replace the current position selector and “Add New Position” checkbox with the existing reusable **Priority Table Component**.

The table should include:

* Search bar
* Filter button
* Settings button
* **Create Position** button

When **Create Position** is clicked, open a dialog for creating a new position. The new position must be scoped to the **current facility**, since it is being created by HR.

The create-position flow must also use the existing **comparison/duplicate-check flow** to detect similar or duplicate positions before saving.

### Selecting and Assigning a Position

Within the positions table:

1. First column: Number.
2. Second column: Selection control (only one position can be selected because a staff member is assigned one position at a time).
3. At the bottom of the dialog, provide an **Assign Position** button.

When clicked, the selected position should be assigned to the current staff member whose details are being edited.

Therefore, the flow should support both:

* Creating a new position with duplicate checking.
* Selecting and assigning an existing position to a staff member.

### HR Positions Tab

The main **HR screen** should also have a dedicated **Positions** tab with complete functionality.

The Positions screen should include the full positions table and support:

* Create
* Edit
* Soft delete
* Permanent delete
* Restore
* Close
* View details

Clicking a position should open its detailed page, while editing should open the appropriate edit flow and save the changes correctly.

Overall, the **Positions module should be fully implemented end-to-end**, including the UI, backend operations, database operations, facility scoping, duplicate checking, assignment to staff, and all standard CRUD/restore functionality.
