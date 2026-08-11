# Clinical tab — Urgent

## 1. Tab strip

- Label: `clinicalSectionUrgentLabel`
- Icon: `Icons.priority_high_outlined`
- Count source: `state.urgentCount`
- Count tone: `AppTabCountTone.danger`
- Deep-link `section`: `urgent`
- Tab gate: `ClinicalUrgentAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same as Pending; Export / Print absent; date enabled.

## 3. Table

- Scope: urgent non-terminal
- Default columns: same as Pending
- Status / detail chip: `clinicalUrgentSummaryLabel` gated by `ClinicalUrgentAtomPermissions.urgentChip`
- Row tint for urgent
- Storage: `clinical_urgent` / `clinical_cw_urgent`

## 4. Advanced filters / search fields

Shared filters; urgency group especially relevant.

## 5. Primary / secondary / row actions

Same next-action / encounter / Quick Actions stack as Pending.

## 6. Dialogs from this tab

Same Clinical + **reused** clinical_actions stack.

## 7. Nested / follow-on

Same encounter panels.

## 8. Forms (summary)

Same clinical forms as Pending.

## 9. Print / labels / preview

Encounter print summary only.

## 10. Loading / empty / error / success

Shared clinical feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail / printSummary | read ∩ |
| urgentChip | read ∩ |
| Mutations / clinical writes | write ∪ |
| Lab / radiology / pharmacy / admission | dedicated write ∪ |
| routeEntry | catalog entry |
