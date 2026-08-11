# OPD tab — Arrivals

## 1. Tab strip

- Label: `opdSectionArrivalsLabel`
- Icon: `Icons.event_outlined`
- Count source: `state.arrivalCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `arrivals` (alias `appointments`)
- Tab gate: `OpdArrivalsAtomPermissions.tab`
- **Omitted when unauthorized**
- Category filter: arrival category only

## 2. Search / Filters / Settings / Export / Print / context

Same board toolbar: **Filters → Settings → Export → Start OPD**

- Start OPD omitted without `OpdArrivalsAtomPermissions.startEncounter`
- Table Print: **absent**

## 3. Table

- Row model: arrival-category `_OpdTableItem` (appointments / check-in)
- Row select → Appointment Actions (`omitPrimaryAction: true`)
- Default columns: Patient, Visit type, Arrival time, Status, Next action (when front-desk/start gates allow column)
- Column choices: Arrival mode, Provider, Waiting time, Encounter, Category

## 4. Advanced filters / search fields

Same shared OPD filter groups / search fields / arrival date filter as board.

## 5. Primary / secondary / row actions

- Start OPD on search bar
- Next action: Check in / Continue (front-desk) when authorized
- Row → Appointment Actions hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Appointment Actions | **reused** |
| Encounter (check-in / Start OPD) | **reused** |
| Nested reschedule / cancel | **reused** front-desk |

## 7. Nested / follow-on

Appointment hub → reschedule / cancel / encounter; new-patient mode requires patient:write locally.

## 8. Forms (summary)

Appointment schedule fields; encounter arrival/provider form; cancel reason.

## 9. Print / labels / preview

- Table Print: **absent**
- Print summary only if a path reaches Flow Actions (not primary on Arrivals)

## 10. Loading / empty / error / success

Shared board empty/success/loading.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select | board read ∪ |
| Start OPD | encounter source |
| Check-in / Continue / hub writes | `opdFrontDeskActionRequirement` |
| Nested billing/admission | _(n/a)_ on arrival stages |
