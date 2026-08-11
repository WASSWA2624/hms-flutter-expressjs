# IPD tab — Active patients

## 1. Tab strip

- Label: `ipdActivePatientsTabLabel`
- Icon: `Icons.local_hospital_outlined`
- Count source: `state.activePatientCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `active` (aliases `active-patients`, …)
- Tab gate: `IpdActivePatientsAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Same queue toolbar: **Filters → Settings → Export → Start admission**

- Manage beds not mounted
- Table Print: **absent**

## 3. Table

- Row model: active-scope `IpdAdmissionSummary`
- Row select → admission detail
- Default columns: Patient, Location, Admitted at, Status, Next action (when tab readable)
- Column choices: Owner role, Length of stay

## 4. Advanced filters / search fields

Same IPD filter set; transfer-status group included for Active.

## 5. Primary / secondary / row actions

- Start admission when operational write allows
- Next actions: approve/assign/transfer/nursing/discharge/theatre/continue care as stage dictates
- Row → detail (Open billing available in detail when billing read)

## 6. Dialogs from this tab

Same admission detail + mutation dialogs as Admission queue (section atoms from `IpdActivePatientsAtomPermissions`).

## 7. Nested / follow-on

Full detail Quick Actions including clinical orders, ICU start, discharge, transfers, billing navigation. `panel=` deep links per shared chrome.

## 8. Forms (summary)

Same admission/transfer/nursing/discharge/clinical forms as Admission queue.

## 9. Print / labels / preview

- Table Print: **absent**

## 10. Loading / empty / error / success

Shared IPD queue feedback.

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Start admission / operational next actions | operational write ∪ |
| Clinical next actions / orders | clinical write ∩ |
| Open billing / billing panel | ∩ `billing:read` |
| Manage beds | not mounted |
