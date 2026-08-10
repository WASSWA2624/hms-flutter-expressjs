### Refined version

On the HR screen, under **Staff Details**, there is an **Assign Department** action button. When clicked, it should open the **Assign Department** dialog.

Please update the dialog as follows:

* On large screens, place the **Department** and **Unit** select fields on the same row.
* Place the **Start Date** and **End Date** fields on the same row as well, to make the assignment process more compact and user-friendly.
* If the staff member already has a department assigned, change the action button from **Assign Department** to **Change Department**.
* When **Change Department** is selected, open the same dialog in change mode with the staff member’s current department, unit, and assignment details pre-filled.
* The **Start Date** should default to the current date.
* The **End Date** should be optional. If it is left blank, the assignment should remain active indefinitely until the department is changed or the assignment is ended.
* If an **End Date** is specified, the staff member’s department assignment and related access should automatically become inactive on that date, and access to that department should be revoked accordingly.
* When changing departments, the system should properly terminate the previous department assignment and create the new assignment based on the selected dates.

Overall, the department assignment should behave like a **time-bound staff-to-department relationship**, with automatic access activation and deactivation based on the assignment dates.

Do not make any major changes to the staff details UI layout