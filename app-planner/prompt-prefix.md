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
Still on the clinical screen, update the patient details dialog and refactor the clinical action workflows into reusable shared components.

## Clinical Actions Refactor
In the patient details dialog, the **Clinical actions** section includes actions such as:
* Add note
* Add diagnosis
* Request lab
* Request radiology
* Prescribe
* Add procedure
* Care plan
* Refer
* Request admission
* Follow up
* Complete disposition
* Print summary
These actions and their dialogs will be reused across different modules in the app.
Convert these clinical action dialogs/workflows into reusable components and place them in an appropriate shared folder under:`frontend/lib/shared`
Use a suitable subfolder structure that clearly shows these are reusable clinical actions, modules, dialogs, or components.

## Reusability
Each reusable clinical action component should accept the required data through parameters or props so it can be used consistently across the app.
Ensure the same reusable components are used wherever these actions appear, instead of recreating similar dialogs or workflows in different modules.

## Real-Time Updates
Ensure these dialogs and all nested UI update the database in real time.
The frontend should also update immediately when changes happen.
This is important so users working in different units can see system changes as they happen.

## Full Codebase Refactor
Review and refactor the entire codebase to reuse these new shared clinical action components.
Check all relevant modules and screens, including:
* Patients
* Billing
* Claims
* OPD
* Emergency
* IPD
* ICU
* Nursing
* Clinical
* Lab
* Radiology
* Pharmacy
* Discharge
* Theater
* Settings
* Setup
Ensure these modules reuse the shared clinical action dialogs/components wherever applicable.
The goal is to avoid duplicate implementations and ensure maximum uniformity, reusability, and consistency across the app.
