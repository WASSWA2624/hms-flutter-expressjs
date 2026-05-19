You are provided with the following attached zip folders:

- `backend.zip`
- `frontend.zip`
- `app-planner.zip`

Review and update/refactor the attached codebase to implement the task appended below.

## Requirements

Inspect the relevant parts of the backend, frontend, and app-planner codebases before making any changes.

Treat the following files as the single source of truth:

- `app-planner\app-write-up.zip`
- `app-planner\opd-flow.zip`
- `app-planner\ipd-flow.zip`

Respect all rules defined in:

- `backend\app-planner\app-rules`
- `frontend\app-planner\app-rules`

Before creating or modifying components, first check the existing shared components folder for reusable code/components:

`frontend\lib\shared`

Reuse existing shared components wherever applicable instead of reinventing them.

The goal is to achieve maximum UI uniformity, code reusability, and component consistency across the entire implementation.

If a suitable shared component already exists, reuse it instead of creating a new one.

If you find any component that is reused, or will be reused in multiple places throughout the module or app, convert it into a reusable shared component.

This should be treated as a major UI optimization, uniformity, and reusability refactor for the entire implementation, including but not limited to:

- Screens
- Modules
- Modals
- Forms
- UI sub-components
- Components
- Any other reusable UI or code patterns

Update or refactor only the files required to implement the appended task.

Create new files only where necessary.

Update the backend only if it is strictly necessary.

Preserve the original folder structure and place all created or modified files in their correct respective paths.

## Output Requirement

Return a single zip folder named:

`hms.zip`

The `hms.zip` folder must contain only:

- Files that were modified
- Files that were newly created

Do not include unchanged files.

## Deleted or Renamed Files

If any files are deleted or renamed, include an appropriate script that can safely delete or rename those files.

The script should preserve the intended folder paths and apply only the required delete or rename operations.

# Task: Nursing Module Refactor and UI Improvements

Update and refactor the Nursing screen/module.

## Summary Cards

At the top of the Nursing screen, there are summary cards such as:

- Assigned ward / assigned duties
- Urgent
- Medication due
- Handover pending
- Transfer pending
- Discharge pending

When any of these cards are clicked, open a dialog showing the list of patients that belong to that category.

Each dialog should use the appropriate reusable list/table component and should show only the relevant patients for that selected category.

## Main Worklist Cleanup

Remove the following from the main Nursing screen:

- `Ward worklist`
- The description: `Patients needing observations, medication, handover, transfer, or discharge coordination.`

The main list should show all patients accessible to the nurse.

Nurses should be able to search for patients directly from the main list.

More detailed searching should be handled through the existing Advanced Filters dialog.

## Worklist Table

Replace the current Nursing worklist with the reusable shared table/list component.

Use the table’s built-in search functionality instead of a separate custom search bar.

The table should show the most important patient/nursing columns by default.

Globally update the table component so that:

- Column headers are clickable by default.
- Clicking a column header opens a dropdown.
- The dropdown allows the user to swap/change the displayed column.
- The table should show at least 4 to 5 of the most important columns by default.
- This column-swap behavior should apply globally wherever the shared table component is used.

## Advanced Filters

Keep detailed filters inside the Advanced Filters dialog.

The main screen should not be cluttered with queue scope or other detailed filters.

Make the Advanced Filters dialog comprehensive enough for Nursing workflows.

## Patient Detail Dialog

When clicking a patient, open the shared/global patient detail dialog.

The current patient details are not displayed elegantly enough.

Refactor the patient detail dialog so it is uniform throughout the app and displays patient details clearly and professionally.

## Record Vitals

The Record Vitals modal should be uniform throughout the app because it is used in multiple modules, including OPD, IPD, wards, Nursing, and other medical screens.

Reuse the existing shared Record Vitals component if it already exists.

If it does not exist, create it as a shared component under `frontend/lib/shared`.

Update the `Recorded at` field:

- Do not display it as a raw date/time string input.
- Replace it with the reusable shared date component.
- Replace the time part with the reusable shared time component.

Ensure the Record Vitals form behaves consistently wherever it is used.

Vitals should be saved correctly and displayed immediately after recording.

There should also be a way to edit existing recorded vitals.

## Add Note

The Add Note modal is fine visually and can remain as it is.

Ensure it uses the shared/global Add Note component.

Ensure notes are actually saved and displayed correctly after saving.

## Administer Medication

Improve the Administer Medication modal.

The current form is not clear because it shows dose information without clearly showing which medication is being administered.

Medication administration should be based on already prescribed medications.

The nurse should be able to see prescribed medications and mark/tick that a medication has been administered.

Ensure administration updates the medication status correctly.

There should also be a way to prescribe medication where applicable, since medication may be prescribed from ward workflows by permitted users such as doctors or nurses where allowed.

## Complete Task

Review the Complete Task action.

If it is not mandatory or does not serve a clear workflow purpose, remove it.

## Create Handover

Improve the Create Handover modal.

Replace the `To user ID` field with a searchable select component.

The searchable select should allow searching system users, especially nurses and doctors, by name or other available user details.

Handover notes should remain available as a text field.

Add support for uploading handover documents.

Add support for scanned handover documents, so handovers can include hard-copy notes that have been scanned.

## Escalate

Improve the Escalate modal.

Replace the `To user ID` field with a searchable select component.

The searchable select should allow searching users by name or other available user details.

Keep the escalation message field.

Keep the confirmation requirement for escalation.

## Print Nursing Summary

Update Print Nursing Summary to use the global reusable print component already defined in the app.

Do not print raw UI screens.

The printed nursing summary should use the global print template and display cleanly.

## Observations and Vitals Display

Recorded observations and vital signs should display clearly in the patient detail dialog.

The current observations section only shows some vital signs.

Ensure recorded vital signs are displayed consistently and completely.

Add the ability to edit recorded observations/vitals where appropriate.

## Nursing Actions

Review the Nursing actions shown in the patient detail dialog.

If there are other relevant nursing tasks that should be available, add them where appropriate.

Ensure the nursing action forms feel complete and are easy to use.

## Synchronization

Ensure all Nursing module actions are synchronized with the backend and reflected in the UI in real time.

This includes:

- Summary cards
- Worklist rows
- Patient details
- Vitals
- Notes
- Medication administration
- Handovers
- Escalations
- Print summaries
- Any other affected nursing data

Avoid unnecessary full-page or full-workspace reloads.

After an action, update only the affected rows, counters, badges, panels, dialogs, or sections.

## Responsiveness and Reusability

Ensure all tables, dialogs, modals, forms, and patient detail views are responsive.

Maximize reuse of shared components.

Create new shared components only when necessary.

Ensure the Nursing module is clean, consistent, responsive, and easy to use.