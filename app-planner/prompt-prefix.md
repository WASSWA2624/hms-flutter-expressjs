You are provided with the following attached zip folders:
* `backend.zip`
* `frontend.zip`
* `app-planner.zip`
Review and update/refactor the attached codebase to implement the task appended below.

## Requirements
Inspect the relevant parts of the backend, frontend, and app-planner codebases before making any changes.
Treat the following files as the single source of truth:
* `app-planner\app-write-up.zip`
* `app-planner\opd-flow.zip`
* `app-planner\ipd-flow.zip`
Respect all rules defined in:
* `backend\app-planner\app-rules`
* `frontend\app-planner\app-rules`
Before creating or modifying components, first check the existing shared components folder for reusable code/components:
`frontend\lib\shared`
Reuse existing shared components wherever applicable instead of reinventing them.
The goal is to achieve maximum UI uniformity, code reusability, and component consistency across the entire implementation.
If a suitable shared component already exists, reuse it instead of creating a new one.
If you find any component that is reused, or will be reused in multiple places throughout the module or app, convert it into a reusable shared component.
This should be treated as a major UI optimization, uniformity, and reusability refactor for the entire implementation, including but not limited to:
* Screens
* Modules
* Modals
* Forms
* UI sub-components
* Components
* Any other reusable UI or code patterns
Update or refactor only the files required to implement the appended task.
Create new files only where necessary.
Update the backend only if it is strictly necessary.
Preserve the original folder structure and place all created or modified files in their correct respective paths.

## Output Requirement
Return a single zip folder named:
`hms.zip`
The `hms.zip` folder must contain only:
* Files that were modified
* Files that were newly created
Do not include unchanged files.

## Deleted or Renamed Files
If any files are deleted or renamed, include an appropriate script that can safely delete or rename those files.
The script should preserve the intended folder paths and apply only the required delete or rename operations.

# Task

Still on the clinical screen, update the patient details dialog workflows for **Request Admission**, **Follow Up**, and **Complete Disposition**.

## Request Admission / Admit Patient

Update the **Request Admission** form.

Instead of only selecting an available bed, the form should allow the user to view and select admission details clearly, including:

* Ward
* Room
* Bed
* Bed availability

The form should check available beds before admission is requested.

The user should be able to see which wards, rooms, and beds are available, then submit the admission request for the patient.

## Follow Up

Update the **Follow Up** form.

Replace the current follow-up date text input with:

* The reusable date component
* The reusable time component

The form should capture the patient as a follow-up patient using the selected follow-up date and time.

## Complete Disposition

Update the **Complete Disposition** workflow.

Replace the disposition reason field with a searchable select component.

Pre-fill the reason list with possible disposition reasons.

Keep the notes field optional.

When the disposition is completed, the patient encounter should be removed completely from OPD.

If the patient is moved or assigned elsewhere after disposition, they should no longer appear in OPD.

