# Discharge tab — Planned

## 1. Tab strip

- Label: `dischargeSectionPlanned`
- Icon: `Icons.event_available_outlined`
- Count source: `state.plannedCount` (client filter `isPlannedDischarge`)
- Sibling tabs: loaded-queue / client-filter model (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `planned`
- Tab gate: `DischargePlannedAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Same queue chrome as All; date filter **off**; no strip Plan/Clearance; no table Print

## 3. Table

- Row model: `IpdAdmissionSummary` (planned only)
- Row select → detail
- Default columns:
  1. Patient
  2. Location
  3. Clearance phase (`ipdDischargeClearancePhaseLabel`)
  4. Status
  5. Next action
- Storage: `discharge_planned` / `discharge_cw_planned`
- Mobile: clearance phase when present

## 4. Advanced filters / search fields

- Status group (shared list); date filter **off**

## 5. Primary / secondary / row actions

- Next-action: Manage clearance (`dischargeManageClearanceAction`) for planned rows (write)
- Row select → detail → Continue into planning/clearance

## 6. Dialogs from this tab

Same as All: detail, planning, pharmacy, clinicalSummary print.

## 7. Nested / follow-on

Same cross-module Open\* and finalize/plan paths as All.

## 8. Forms (summary)

Planning clearance + pharmacy request forms (shared).

## 9. Print / labels / preview

- Table Print: **absent**
- Detail print when summary present (`DischargePlannedAtomPermissions.printSummary`)

## 10. Loading / empty / error / success

Shared Discharge patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | `DischargePlannedAtomPermissions.*` → workspace read ∪ |
| nextActionClearance / write / pharmacy | clinical write |
| printSummary | read ∪ |
| Billing / pharmacy / operations / nursing panels | nested ∩ as All |
| Export | ungated |
| Table Print | n/a |
