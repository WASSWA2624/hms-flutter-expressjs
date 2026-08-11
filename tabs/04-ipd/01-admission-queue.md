# IPD tab — Admission queue

## 1. Tab strip

- Label: `ipdAdmissionQueueTabLabel`
- Icon: `Icons.bed_outlined`
- Count source: `state.admissionQueueCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `admission-queue` (aliases `queue`, …)
- Tab gate: `IpdAdmissionQueueAtomPermissions.tab`
- **Omitted when unauthorized**
- Default section when unspecified

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Start admission**

- Filters label: `ipdFiltersLabel`
- Start admission: `ipdStartAdmissionAction` — omitted without `IpdAdmissionQueueAtomPermissions.startAdmission`
- Manage beds: **not** mounted as strip primary on this tab
- Table Print: **absent**

## 3. Table

- Row model: `IpdAdmissionSummary` (`IpdQueueScope.admissionQueue`)
- Row select → admission detail dialog
- Default columns (5 when next-action shown): Patient, Location, Admitted at, Status, Next action
- Column choices: Owner role, Length of stay
- Next-action column mounts for readers (`ipdBoardShowsNextActionColumn`); write buttons hide via gates
- Mobile: title, admission id caption, location + status meta

## 4. Advanced filters / search fields

- Search fields: patient, patient id, admission, encounter, ward, bed, status, transfer, icu
- Text filters: patient id, admission id, encounter id, phone
- Groups: Ward; Transfer status (on this tab); Has active bed; Critical alert; (+ ICU filters as coded)
- Date range on admitted-at

## 5. Primary / secondary / row actions

- Start admission (search bar)
- Next action: Approve / Assign bed / Transfer / Nursing note / Discharge / Theatre handover / Continue care (kind from `ipdBoardNextActionKind`)
- Row → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned |
| Start admission | IPD-owned |
| Assign bed / approve / reject / transfer / nursing / discharge | IPD / **reused** shared |

## 7. Nested / follow-on

Detail Quick Actions + `panel=` / `action=` deep links (beds/transfer/nursing/discharge/…). Billing/insurance panel when ∩ `billing:read`. Navigate ICU/Theater/Nursing/Physio/Billing when eligible.

## 8. Forms (summary)

Start admission identity/ward/bed fields; transfer request/update; nursing note; discharge planning; clinical order forms; approve/reject confirms.

## 9. Print / labels / preview

- Table Print: **absent**
- No IPD-owned chart print on this tab from traced call sites

## 10. Loading / empty / error / success

- Empty: `ipdNoAdmissionsTitle` / `ipdNoAdmissionsBody`
- Success: `_showSaved`
- Loading/retry: scaffold; detail linear progress when refreshing

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / Continue care label | board read ∪ |
| Start / Approve / Assign bed / Transfer / Reject | operational write ∪ |
| Nursing / Discharge / clinical orders | clinical write ∩ |
| Billing / insurance panel / Open billing | ∩ `billing:read` (+ module) |
| Manage beds | admin bed-manage (not primary here) |
| `panel=` / `action=` | `ipdFocusedMutationRequirement` |
