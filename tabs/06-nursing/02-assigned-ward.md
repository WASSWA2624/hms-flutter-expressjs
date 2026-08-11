# Nursing tab — Assigned ward

## 1. Tab strip

- Label: `nursingScopeAssignedWardLabel`
- Icon: `Icons.local_hospital_outlined`
- Count source: `state.assignedWardCount` (null when 0)
- Count tone: default (unset)
- Deep-link `scope`: `assigned-ward` (aliases `assigned_ward`, `ward`)
- Tab gate: `NursingAssignedWardAtomPermissions.tab` = `nursingWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same as All: **Filters → Settings → Export → Shift context**; Print toolbar absent; date enabled.

## 3. Table

- Same chrome as All
- Default columns: patient, location, task_type, status + next_action
- Entity `matchesScope(assignedWard)` returns true for every item (same membership behavior as all in presentation filtering)
- Storage: `nursing_assignedWard` / `nursing_cw_assignedWard`

## 4. Advanced filters / search fields

Shared nursing worklist filters + date.

## 5. Primary / secondary / row actions

Same next-action cascade and detail Quick Actions as All.

## 6. Dialogs from this tab

Same Nursing + **reused** clinical stack as All.

## 7. Nested / follow-on

Billing panel / open billing; Open ICU; print summary; clinical nested.

## 8. Forms (summary)

Same as All.

## 9. Print / labels / preview

Detail print summary only; worklist Print absent.

## 10. Loading / empty / error / success

Shared nursing feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail | read ∪ |
| Writes / next-action mutations / printSummary | write ∪ |
| Medication atoms | medication administer ∩ |
| medicationsPanel | pharmacy:read |
| shiftContext | shift req |
| billingPanel / openBilling | billing read |
| routeEntry | catalog entry |
