# OPD tab — All worklist

## 1. Tab strip

- Label: `opdSectionAllLabel`
- Icon: `Icons.dashboard_outlined`
- Count source: `summaryCounts.allOpdPatients` (fallback combined `_tableItems` length); filtered total when this tab is active with search/advanced filters
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: omitted / empty
- Tab gate: `OpdAllAtomPermissions.tab` = ∪ `patient:read` \| `clinical:read` + `scheduling-queue`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start OPD**

- Search hint: `opdSearchHint`
- Filters: `commonFiltersActionLabel` + date `opdArrivalDateFilterLabel` + Close `commonCloseActionLabel`
- Settings / Export / Print: common table labels; Export/Print gated by ∩ `evidence:export`
- Start OPD: `opdStartWalkInAction` — omitted without `OpdAllAtomPermissions.startEncounter`

## 3. Table

- Row model: `_OpdTableItem` (appointments + queue + triage + active flows)
- Row select → Flow / Queue / Appointment Actions by payload (`_openOpdTableItemActions`)
- Default columns (5): Patient name, Category, Doctor (provider), Status, Next action (when Next action unauthorized, promote from choices so defaults stay at **5**)
- Column choices: Arrival mode, Visit type, Wait time, Arrival time, OPD encounter (minus any promoted into defaults)
- Patient name cell: name only (atomic); identifier on mobile caption / search
- Mobile: arrival mode, waiting time, status; optional next-action trailing
- Main-tab viewport: bounded, non-shrinkWrap, pinned footer, empty-row padding
- Export/Print: full filtered membership for this tab

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

From hubs: reschedule/cancel appointment; prioritize/move/assign queue; vitals / payment / disposition / admission handoff / Print; encounter new-patient mode (patient:write dialog-local).

## 8. Forms (summary)

Encounter check-in, vitals, billing payment, disposition, admission handoff, appointment reschedule/cancel, queue status/doctor — shared OPD dialogs.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList`
- From Flow Actions: Print → `showPrintOpdSummaryDialog`

## 10. Loading / empty / error / success

- Empty: `opdNoFlowsTitle` / `opdNoFlowsBody`
- Success: `opdSavedMessage`
- Loading/retry: workspace scaffold

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Export / Print | ∩ `evidence:export` |
| Start OPD | `opdEncounterPermissionRequirement` |
| Next actions | vitals / billing / reception / doctor / admission / front-desk source gates |
| Appointment/queue hub writes | `opdFrontDeskActionRequirement` |
| `panel=` deep link | `opdFocusedPanelRequirement` |
| Route entry | catalog ∩ `opd:read` |
