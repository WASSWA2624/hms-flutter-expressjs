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

On the clinical screen, under the patient details dialog, improve the **Add Procedure** workflow.

The **Add Procedure** button currently opens a dialog with two fields:

* Procedure code
* Procedure or minor surgery

## Procedure Fields

Convert these fields into searchable select components.

Use the existing reusable searchable select component already available in the app.

## Procedure Data

Populate the procedure options with common procedures and minor surgeries.

Add at least **5,000 procedures**.

## Multiple Procedures

Allow the user to add more than one procedure at the same time.

The workflow should make it easy to select, review, and add multiple procedures.

## Search Performance

Ensure the procedure search is smooth and responsive.

Typing should not become sluggish, even when searching through a large procedure catalog.

## UI and UX

Improve the layout, display, and overall user experience of the Add Procedure dialog.

The process of adding procedures should be clean, simple, and easy to use.

