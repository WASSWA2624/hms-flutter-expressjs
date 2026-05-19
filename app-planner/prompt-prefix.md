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
Perform a major app-wide refactor and optimization focused on UI consistency, component reusability, performance, and real-time data synchronization.

## Main Goal
Refactor the app so commonly used dialogs, action components, UI sections, and repeated patterns are defined once as reusable shared components.
Place reusable components under the appropriate folders inside:`frontend/lib/shared`
Use a clear folder structure so each shared component type is easy to locate and reuse.

## Scope
Review the following modules/screens:
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

## Patient Screen Refactor
Start by reviewing the **Patients** screen.
Identify all dialogs, commonly used components, action components, repeated UI patterns, and repeated workflows.
Convert reusable items into shared components.
Each reusable component or dialog should be declared only once in the shared folder and reused wherever needed.

## App-Wide Component Refactor
Apply the same refactor across all listed modules.
Look for similar components that can be merged into one reusable component that can be customized through properties/parameters.
For example, if different modules use similar dialogs such as:
* Triage dialog
* Lab request dialog
* Radiology request dialog
* Pharmacy request dialog
* Patient action dialogs
* Clinical action dialogs
* Common form dialogs
* Common list/table components
They should use the same shared component so the UI and behavior remain consistent across the app.

## Uniformity Requirement
When the same workflow is opened from different modules, the user should see the same UI and behavior.
For example, a lab request opened from IPD, OPD, Clinical, Nursing, or any other module should use the same shared lab request dialog.
Do not reinvent or duplicate the same workflow in different modules.

## Preserve Current Functionality
Do not alter existing functionality.
Refactor, clean up, optimize, and improve reuse while preserving current behavior.

## Real-Time Synchronization
Ensure the UI, backend, and database remain synchronized.
When data changes in the database, the UI should update immediately where applicable.
Users working in different units should be able to see system updates as they happen.

## Performance Optimization
Optimize the UI and code for efficiency.
Ensure the app does not become sluggish during normal use.
Improve repeated components, dialogs, data loading, and UI updates so the app remains smooth and responsive.
