# Clinical tab — Completed

## 1. Tab strip

- Label: `clinicalSectionCompletedTodayLabel`
- Icon: `Icons.task_alt_outlined`
- Count source: `state.completedCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `completed` (aliases `completed-today`, `completed_today`, `closed`, `done`)
- Tab gate: `ClinicalCompletedAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same as Pending; Export / Print absent; date enabled.

## 3. Table

- Scope: terminal + today
- **Default columns:** patient, queue, **encounterType**, status, nextAction
- Storage: `clinical_completed` / `clinical_cw_completed`

## 4. Advanced filters / search fields

Shared worklist filters + date.

## 5. Primary / secondary / row actions

- Vitals / disposition actions hidden when `entry.isTerminal`
- Open encounter still available; post-completion writes use write atoms (`reopen` maps write)

## 6. Dialogs from this tab

Same Clinical encounter shell + **reused** clinical_actions when still eligible; print summary.

## 7. Nested / follow-on

Same detail panels; terminal entries suppress some mutation entry points in UI.

## 8. Forms (summary)

Same clinical forms when write actions remain mounted.

## 9. Print / labels / preview

Encounter print summary only.

## 10. Loading / empty / error / success

Shared clinical feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / printSummary / completedChip / openEncounter | read ∩ |
| Mutations / reopen / clinical writes | write ∪ |
| Lab / radiology / pharmacy / admission | dedicated write ∪ |
| routeEntry | catalog entry |
