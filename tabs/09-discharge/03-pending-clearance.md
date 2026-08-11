# Discharge tab — Pending clearance

## 1. Tab strip

- Label: `dischargeSectionPendingClearance`
- Icon: `Icons.pending_actions_outlined`
- Count source: `state.summaryPendingCount`
- Sibling tabs: loaded-queue / client-filter model (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `pending` (aliases `pending_clearance`, `pending-clearance`, `pendingclearance`)
- Tab gate: `DischargePendingClearanceAtomPermissions.tab` = **pending clearance read ∪** (broader than workspace read)
- Client rows: `!completed && !planned`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export**

- Same queue chrome; date filter **off**; no strip actions; no table Print

## 3. Table

- Row model: `IpdAdmissionSummary` (pending scope)
- Row select → detail
- Default columns:
  1. Patient
  2. Location
  3. Blocking item (`dischargeStatusSummaryPending`)
  4. Status
  5. Next action
- Storage: `discharge_pendingClearance` / `discharge_cw_pendingClearance`
- Mobile: blocking item label

## 4. Advanced filters / search fields

- Status group; date filter **off**

## 5. Primary / secondary / row actions

- Next-action: Start plan (`dischargeStartPlanAction`) for non-completed (write)
- Row select → detail

## 6. Dialogs from this tab

Detail + planning + pharmacy + clinicalSummary print (shared).

## 7. Nested / follow-on

Same planning / cross-module Continue paths.

## 8. Forms (summary)

Plan summary + pharmacy + finalize override when applicable.

## 9. Print / labels / preview

- Table Print: **absent**
- Detail print via pending `printSummary` (pending read ∪)

## 10. Loading / empty / error / success

Shared Discharge patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail / printSummary | `DischargePendingClearanceAtomPermissions.*` → pending read ∪ |
| nextActionPlan / write / pharmacy | clinical write |
| Nested billing / pharmacy / operations / nursing | ∩ as shared clearance gates |
| Export | ungated |
| Table Print | n/a |
