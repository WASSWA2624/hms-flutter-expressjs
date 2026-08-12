# Clinical tab — Assigned to me

## 1. Tab strip

- Label: `clinicalSectionAssignedToMeLabel`
- Icon: `Icons.person_outline`
- Count source: `state.assignedToMeCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `assigned-to-me` (aliases `assigned_to_me`, `assignedtome`, `mine`, `assigned`)
- Tab gate: `ClinicalAssignedToMeAtomPermissions.tab` = `clinicalWorkspaceReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same as Pending: **Filters → Settings → Export → Print**; Export / Print gated by ∩ `evidence:export`; date enabled.

## 3. Table

- Scope: `ClinicalQueueScope.assignedToMe` (non-terminal + `providerUserId` == session user)
- Default columns: patient, queue, provider, status, nextAction (same as Pending)
- Storage: `clinical_assignedToMe` / `clinical_cw_assignedToMe`

## 4. Advanced filters / search fields

Same shared worklist filters + date.

## 5. Primary / secondary / row actions

Same next-action / Open encounter / detail Quick Actions as Pending.

## 6. Dialogs from this tab

Same Clinical-owned encounter shell + **reused** clinical_actions / print / discharge.

## 7. Nested / follow-on

Same encounter detail panels and nested order/billing confirms.

## 8. Forms (summary)

Same clinical action forms as Pending.

## 9. Print / labels / preview

Encounter print summary only; table Print absent.

## 10. Loading / empty / error / success

Shared clinical feedback.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / detail / printSummary | read ∩ |
| Mutations / clinical writes | write ∪ |
| Lab / radiology / pharmacy / admission | dedicated write ∪ |
| dischargeFinancialRead | billing read |
| routeEntry | catalog entry |
| followUpsTab | **n/a** on this atom class |
