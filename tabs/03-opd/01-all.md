# OPD tab — All worklist

## 1. Tab strip

- Label: `opdSectionAllLabel`
- Icon: `Icons.dashboard_outlined`
- Count source: client combined `_tableItems` length (`allItems.length`)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: omitted / empty
- Tab gate: `OpdAllAtomPermissions.tab` = ∪ `patient:read` \| `clinical:read` + `scheduling-queue`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Start OPD**

- Search hint: `opdSearchHint`
- Filters: `commonFiltersActionLabel` + date `opdArrivalDateFilterLabel`
- Settings / Export: common table labels
- Print (toolbar): **absent**
- Start OPD: `opdStartWalkInAction` — omitted without `OpdAllAtomPermissions.startEncounter`

## 3. Table

- Row model: `_OpdTableItem` (appointments + queue + triage + active flows)
- Row select → Flow / Queue / Appointment Actions by payload (`_openOpdTableItemActions`)
- Default columns (5): Patient, Category, Provider, Status, Next action (Next action **omitted when unauthorized** via `opdBoardShowsNextActionColumn`)
- Column choices: Arrival mode, Visit type, Waiting time, Arrival time, Encounter
- Mobile: arrival mode, waiting time, status; optional next-action trailing

## 4. Advanced filters / search fields

Filter groups: Arrival range preset, Category, Visit type, Queue, Status, Provider, Billing, Next action, Triage scope.  
Search fields: patient, patient number, encounter id, phone, provider, queue, status, visit type, billing, next action.  
Date range on arrival/time.

## 5. Primary / secondary / row actions

- Strip: Start OPD
- Next-action cell: stage-aware board actions (check-in, vitals, pay, assign doctor, doctor review, disposition, admission handoff, correct stage, department handoff) gated per kind
- Row select → matching hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Flow Actions | **reused** |
| Appointment Actions | **reused** |
| Queue Actions | **reused** |
| Start encounter | **reused** |

## 7. Nested / follow-on

From hubs: reschedule/cancel appointment; prioritize/move/assign queue; vitals / payment / disposition / admission handoff / print summary; encounter new-patient mode (patient:write dialog-local).

## 8. Forms (summary)

Encounter check-in, vitals, billing payment, disposition, admission handoff, appointment reschedule/cancel, queue status/doctor — shared OPD dialogs.

## 9. Print / labels / preview

- Table Print: **absent**
- From Flow Actions: Print summary → `showPrintOpdSummaryDialog`

## 10. Loading / empty / error / success

- Empty: `opdNoFlowsTitle` / `opdNoFlowsBody`
- Success: `opdSavedMessage`
- Loading/retry: workspace scaffold

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Start OPD | `opdEncounterPermissionRequirement` |
| Next actions | vitals / billing / reception / doctor / admission / front-desk source gates |
| Appointment/queue hub writes | `opdFrontDeskActionRequirement` |
| `panel=` deep link | `opdFocusedPanelRequirement` |
| Route entry | catalog ∩ `opd:read` |
