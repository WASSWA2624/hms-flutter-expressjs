# OPD tab — Triage

## 1. Tab strip

- Label: `opdSectionTriageLabel`
- Icon: `Icons.monitor_heart_outlined`
- Count source: board TRIAGE membership (same rows as the Triage table); when Triage is active and search/filters narrow, badge uses that filtered total
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `triage`
- Tab gate: `OpdTriageAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start OPD**

- Filters: `commonFiltersActionLabel` + date `opdArrivalDateFilterLabel` + Close `commonCloseActionLabel`
- Triage scope filter group present (`opdTriageScopeFilterLabel`: waiting/urgent/emergency/routine/service-only)
- Start OPD omitted without `OpdTriageAtomPermissions.startEncounter`
- Export/Print gated by ∩ `evidence:export`

## 3. Table

- Row model: triage-category `_OpdTableItem`
- Row select → Flow Actions
- Default columns (5): Patient name, Wait time, Doctor (provider), Status, Next action (Next action **omitted when unauthorized** via `opdBoardShowsNextActionColumn`)
- Column choices: Visit type, Arrival mode, Arrival time, OPD encounter
- Status badge uses triage tone for triage category
- Mobile: arrival mode, waiting time, status; optional next-action trailing

## 4. Advanced filters / search fields

Shared OPD filters including triage scope + arrival date. Footer: Clear filters → Apply filters → Close.

## 5. Primary / secondary / row actions

- Start OPD (search bar) when encounter gate allows
- Next action: Record vitals / Assign doctor / Correct stage (source gates) when authorized
- Row → Flow Actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Flow Actions | **reused** |
| Record vitals / assign / routing nested | **reused** opd_actions |
| Start encounter | **reused** |

## 7. Nested / follow-on

From Flow Actions / next-action: vitals dialog, assign doctor, correct stage. Billing/admission panels _(n/a)_ on triage stages per access map.

## 8. Forms (summary)

Vitals fields; provider assignment; stage correction; encounter start form.

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printOpdWorkspaceList`
- Flow Actions Print: `commonPrintActionLabel` + shared preview when stage allows

## 10. Loading / empty / error / success

Shared board feedback; success after hub/vitals mutations. Forbidden: `routeForbiddenTitle` when board read denied.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Export / Print | ∩ `evidence:export` |
| Start OPD | encounter source |
| Vitals next-action | `opdVitalsActionRequirement` |
| Assign doctor / Correct stage | `opdReceptionActionRequirement` |
| Nested billing/admission | _(n/a)_ on triage |
| Route entry | catalog ∩ `opd:read` |
