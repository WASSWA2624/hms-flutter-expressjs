### Refined Prompt

You are provided with the following attached zip folders:

* `backend.zip`
* `frontend.zip`
* `app-planner.zip`

Review and update/refactor the attached codebase to implement the task below.

# Requirements

Inspect the relevant parts of the backend, frontend, and app-planner codebases before making any changes.

Treat the following files as the single product and flow source of truth:

* `app-planner\app-write-up.zip`
* `app-planner\opd-flow.zip`
* `app-planner\ipd-flow.zip`

Use the planner and rules files only for alignment and implementation guidance.

Respect all rules defined in:

* `backend\app-planner\app-rules`
* `frontend\app-planner\app-rules`

Before creating or modifying components, first check the existing shared components folder:

`frontend\lib\shared`

Reuse existing shared components wherever applicable instead of reinventing them.

The goal is maximum UI uniformity, code reusability, and component consistency across the entire implementation.

If a suitable shared component already exists, reuse it instead of creating a new one.

If any component is reused, or will be reused in multiple places throughout the module or app, convert it into a reusable shared component.

This should be treated as a major UI optimization, uniformity, and reusability refactor across the implementation, including but not limited to:

* Screens
* Modules
* Modals
* Forms
* UI sub-components
* Components
* Any other reusable UI or code patterns

Update or refactor only the files required to implement the task.

Create new files only where necessary.

Update the backend only if it is strictly necessary.

Preserve the original folder structure and place all created or modified files in their correct respective paths.

# Output Requirement

Return a single zip folder named:

`hms.zip`

The `hms.zip` folder must contain only:

* Files that were modified
* Files that were newly created

Do not include unchanged files.

# Deleted or Renamed Files

If any files are deleted or renamed, include an appropriate script that can safely delete or rename those files.

The script should preserve the intended folder paths and apply only the required delete or rename operations.

# Task: Nursing Screen Refactor

Update and refactor the Nursing screen to improve layout, reusability, responsiveness, filtering, patient details, and real-time synchronization.

## Overview Badges

Keep the overview badges/cards at the top of the Nursing screen, including:

* Assigned ward
* Urgent
* Medication due
* Handover pending
* Transfer pending
* Discharge pending

Ensure these badges remain clear, consistent, and properly synchronized with backend data.

## Worklist

Replace the current Nursing worklist with the reusable shared table/list component.

Use the shared table’s built-in search functionality instead of a separate custom search bar.

The worklist should remain clean and focused on the most important nursing information.

## Search and Filters

Remove the visible **Queue scope** filter from the main Nursing screen.

Move **Queue scope** and other detailed filters into the Advanced Filters dialog.

Make the Advanced Filters dialog comprehensive and easy to use.

It should include all relevant Nursing worklist filter options, such as:

* Patient
* Admission
* Encounter
* Ward
* Room
* Bed
* Observation
* Task type
* Status
* Priority
* Due time/date
* Assigned nurse
* Shift
* Transfer status
* Handover status
* Discharge status

Ensure filtering is backed by the backend where applicable and does not reload the full workspace unnecessarily.

## Patient Details

Remove the selected patient details panel from the main Nursing screen.

Replace it with the global reusable patient detail component that already exists in the shared components.

When a patient is selected, open the global patient detail component instead of showing patient details directly on the main screen.

## Nursing Actions

Move Nursing actions into the patient detail workflow instead of showing them directly on the main Nursing screen.

This includes:

* Record vitals
* Add note
* Administer medication
* Complete task
* Create handover
* Escalate
* Acknowledge transfer
* Any other patient-specific Nursing action

These actions should use reusable shared dialogs/components wherever possible.

## Ward Admission Checklist

Remove the Ward Admission Checklist from the main Nursing screen.

Place it inside an appropriate patient detail modal, workflow, or related dialog instead of keeping it on the main page.

## Patient Sections

Remove the following patient-specific sections from the main Nursing screen:

* Observations
* Medications
* Nursing notes
* Care plans
* Handovers
* Ward activity

Replace these with relevant reusable modals, dialogs, or patient-detail sections so they are available when viewing a selected patient, not always visible on the main screen.

## Shift Context and Roster Assignments

Move the **Shift context** and **Roster assignments** section out of the main Nursing screen.

Place it in an appropriate modal/dialog so nurses can open it when needed without cluttering the main workspace.

## Real-Time Synchronization

Ensure all Nursing actions are synchronized with the backend.

Any change should be reflected in the UI in real time, including updates to:

* Worklist rows
* Overview badges
* Patient detail sections
* Nursing actions
* Observations
* Medications
* Nursing notes
* Care plans
* Handovers
* Ward activity
* Shift and roster information

Avoid full workspace reloads after actions. Refresh only the affected rows, badges, panels, counters, or sections.

## Responsiveness and Reusability

Ensure all modals, dialogs, tables, filters, and patient-detail views display correctly across screen sizes.

Maximize code reusability by using existing shared components first.

Create new shared components only when necessary.

Ensure the Nursing screen is clean, responsive, consistent, and easy to use.
