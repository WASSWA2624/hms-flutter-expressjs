# OPD tab — Active

## 1. Tab strip

- Label: `opdSectionActiveLabel`
- Icon: `Icons.medical_services_outlined`
- Count source: `state.summaryCounts.activeOpd` (fallback `state.activeFlowCount`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `active` (aliases `active_flow`, `encounters`, `flows`)
- Tab gate: `OpdActiveAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

**Filters → Settings → Export → Start OPD**; table Print **absent**.

## 3. Table

- Row model: active-flow-category `_OpdTableItem`
- Row select → Flow Actions (`OpdActiveAtomPermissions.rowSelect`)
- Default columns: Patient, Provider, Visit type, Status, Next action (when any next-action gate allows)
- Column choices: Encounter, Waiting time, Arrival time, Arrival mode

## 4. Advanced filters / search fields

Shared OPD filters; `panel=` deep links often seed status subsets (payment, vitals, doctor, lab, imaging, pharmacy, disposition, admission).

## 5. Primary / secondary / row actions

- Start OPD (search bar) when allowed
- Next actions: vitals, pay consultation, assign doctor, doctor review, disposition, admission handoff, correct stage, department handoff
- Row → Flow Actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Flow Actions | **reused** |
| Stage mutation dialogs via next-action / `panel=` | **reused** opd_actions |
| Start encounter | **reused** |

## 7. Nested / follow-on

Full clinical/billing/admission chain from Flow Actions when source gates allow (payment, vitals, disposition, admission handoff, print summary, referrals, etc.).

## 8. Forms (summary)

Vitals, consultation payment, disposition, admission handoff, doctor assignment, routing — shared dialogs.

## 9. Print / labels / preview

- Table Print: **absent**
- Flow Actions → `showPrintOpdSummaryDialog` (clinical summary)

## 10. Loading / empty / error / success

Shared board feedback; `opdSavedMessage` after mutations.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Start OPD | encounter source |
| Next-action kinds | vitals / billing / reception / doctor / admission source gates (`OpdActiveAtomPermissions.*`) |
| `panel=` deep link | `opdFocusedPanelRequirement` |
| Route entry | catalog ∩ `opd:read` |
