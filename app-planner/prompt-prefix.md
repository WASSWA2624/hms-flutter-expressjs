You are provided with three attached zip folders:

* `backend.zip`
* `frontend.zip`
* `app-planner.zip`

Review and update/refactor the attached codebase to implement the appended task.
## Requirements
Inspect the relevant parts of the backend, frontend, and app-planner codebases before making changes.
Update or refactor only the files required to implement the task.
Create any new files only where necessary.
Preserve the original folder structure and place all created or modified files in their correct respective paths.
## Output Requirement
Return a single zip folder named:
`hms.zip`
The `hms.zip` folder must contain only:
* Files that were modified
* Files that were newly created
Do not include unchanged files.
## Deleted or Renamed Files
If any files are deleted or renamed, include an appropriate script that can be used to delete or rename those files safely.
The script should preserve the intended folder paths and apply only the required delete or rename operations.

# Task
Improve the **Prescribe** dialog UI and workflow.
## Prescribe Form Fields
Update the form to support the following:
* **Available drug**: searchable select component for selecting available drugs.
* **Quantity**: input field for the prescribed quantity.
* **Quantity unit / amount unit**: include the appropriate unit fields where required.
* **Dose amount**: input field for dosage amount.
* **Dose unit**: optional, but should use a searchable select component.
* **Medication route**: keep as a selectable field.
* **Frequency**: keep the current behavior, but improve the UI and add appropriate icons.
* **Duration + duration unit**: combine these into one clean component where the user can enter duration and select the duration unit.
* **Duration unit**: should use a searchable select component.
* **Instructions**: keep this field, since it looks fine.
## Multiple Drug Prescriptions
It should be possible to prescribe more than one drug in the same form.
Design the dialog so the user can add and prescribe multiple drugs easily.
## UI and UX Improvements
Improve the overall design, layout, icons, spacing, and visual appearance of the Prescribe dialog.
The prescribing workflow should be simple, clean, and easy to use.
