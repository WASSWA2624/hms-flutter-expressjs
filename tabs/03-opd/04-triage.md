# OPD tab — Triage

## 1. Tab strip

- Label: `opdSectionTriageLabel`
- Icon: `Icons.monitor_heart_outlined`
- Count source: `state.triageQueueCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `triage`
- Tab gate: `OpdTriageAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

**Filters → Settings → Export → Start OPD**; table Print **absent**.

- Triage scope filter group present in shared advanced filters (`opdTriageScopeFilterLabel`: waiting/urgent/emergency/routine/service-only)

## 3. Table

- Row model: triage-category `_OpdTableItem`
- Row select → Flow Actions
- Default columns: Patient, Waiting time, Provider, Status, Next action (when authorized)
- Column choices: Visit type, Arrival mode, Arrival time, Encounter
- Status badge uses triage tone for triage category

## 4. Advanced filters / search fields

Shared OPD groups including triage scope + arrival date.

## 5. Primary / secondary / row actions

- Start OPD when encounter gate allows
- Next action: Record vitals / Assign doctor / Correct stage (source gates)
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

- Table Print: **absent**
- Flow Actions may expose print summary when stage allows

## 10. Loading / empty / error / success

Shared board feedback.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Start OPD | encounter source |
| Vitals next-action | `opdVitalsActionRequirement` |
| Assign doctor / Correct stage | `opdReceptionActionRequirement` |
| Nested billing/admission | _(n/a)_ on triage |
