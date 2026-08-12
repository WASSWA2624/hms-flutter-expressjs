# OPD tab — Active

## 1. Tab strip

- Label: `opdSectionActiveLabel`
- Icon: `Icons.medical_services_outlined`
- Count source: `summaryCounts.activeOpd` (fallback board ACTIVE membership); filtered when active + narrowed
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active` (aliases `active_flow`, `encounters`, `flows`)
- Tab gate: `OpdActiveAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start OPD**

- Filters: `commonFiltersActionLabel` + date `opdArrivalDateFilterLabel` + Close `commonCloseActionLabel`
- Start OPD omitted without `OpdActiveAtomPermissions.startEncounter`
- Export/Print gated by ∩ `evidence:export`

## 3. Table

- Row model: active-flow-category `_OpdTableItem`
- Row select → Flow Actions (`OpdActiveAtomPermissions.rowSelect`)
- Default columns (5): Patient name, Doctor (provider), Visit type, Status, Next action (when Next action unauthorized, promote from choices so defaults stay at **5**)
- Column choices: OPD encounter, Wait time, Arrival time, Arrival mode (minus any promoted into defaults)
- Patient name cell: name only (atomic)
- Mobile: arrival mode, waiting time, status; optional next-action trailing
- Main-tab viewport: bounded, non-shrinkWrap, pinned footer, empty-row padding
- Export/Print: full filtered Active membership
- `panel=` multi-status filters preserved across Advanced filters unless a single status is applied

## 4. Advanced filters / search fields

Shared OPD filters + arrival date. `panel=` deep links often seed status subsets (payment, vitals, doctor, lab, imaging, pharmacy, disposition, admission).  
Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Start OPD (search bar) when allowed
- Next actions: vitals, pay consultation, assign doctor, doctor review, disposition, admission handoff, correct stage, department handoff (source gates)
- Row → Flow Actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Flow Actions | **reused** |
| Stage mutation dialogs via next-action / `panel=` | **reused** opd_actions |
| Start encounter | **reused** |

## 7. Nested / follow-on

Full clinical/billing/admission chain from Flow Actions when source gates allow (payment, vitals, disposition, admission handoff, print, referrals, etc.).

## 8. Forms (summary)

Vitals, consultation payment, disposition, admission handoff, doctor assignment, routing — shared dialogs.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList`
- Flow Actions → `commonPrintActionLabel` + shared clinical summary preview

## 10. Loading / empty / error / success

- Empty: `opdNoActiveTitle` / `opdNoActiveBody`
- Shared board success `opdSavedMessage` after mutations. Forbidden: `routeForbiddenTitle` when board read denied.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Export / Print | ∩ `evidence:export` |
| Start OPD | encounter source |
| Next-action kinds | vitals / billing / reception / doctor / admission source gates (`OpdActiveAtomPermissions.*`) |
| `panel=` deep link | `opdFocusedPanelRequirement` |
| Nested billing / admission | source gates when stage allows |
| Route entry | catalog ∩ `opd:read` |
