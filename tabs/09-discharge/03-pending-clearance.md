# Discharge tab — Pending clearance

## 1. Tab strip

- Label: `dischargeSectionPendingClearance`
- Icon: `Icons.pending_actions_outlined`
- Count source: `DischargeSectionCounts.pendingClearance` (catalog via `state.summaryPendingCount`); active + search/filters → filtered pending membership of `queue.items`
- Sibling tabs: dedicated unfiltered `DischargeSectionCounts` sibling-count model
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `pending` (aliases `pending_clearance`, `pending-clearance`, `pendingclearance`)
- Tab gate: `DischargePendingClearanceAtomPermissions.tab` = **pending clearance read ∪** (broader than workspace read)
- Client rows: `isPendingClearanceDischarge` (`!completed && !planned`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same queue chrome as All; date filter **on**; strip Plan/Clearance **not mounted** (row next-action; justified)
- Filters: `commonFiltersActionLabel` → Advanced filters; Clear / Apply / Close
- Settings: `commonTableSettings*` + Reset/Apply/Close columns
- Export: ∩ `evidence:export` (`DischargePendingClearanceAtomPermissions.export`)
- Print (toolbar): `commonPrintActionLabel` → `printDischargeWorkspaceList` (same export gate)

## 3. Table

- Row model: `IpdAdmissionSummary` (pending scope)
- Row select → detail
- Default columns (**5**):
  1. Patient
  2. Location
  3. Blocking item (`dischargeStatusSummaryPending`)
  4. Status
  5. Next action
- Column choices: target date, clearance phase, discharged at, admitted at (shared column catalog)
- Storage: `discharge_pendingClearance` / `discharge_cw_pendingClearance`
- Mobile: blocking item label; compact next-action

## 4. Advanced filters / search fields

- Status group (shared list); date filter **on** (`dischargeDateFilterLabel` / From / To)
- Same `DischargeWorklistQuery` model as table + active tab count

## 5. Primary / secondary / row actions

- Next-action: Start plan (`dischargeStartPlanAction`) for non-completed (write)
- Row select → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail (`dischargeDetailTitle`; identity in body; pinned footer) | Discharge-owned |
| Planning (`showDischargePlanningDialog` + Pending create/update gates) | Discharge-owned |
| Pharmacy request | Discharge-owned |
| Print clinical summary | **reused** `PrintDocumentTemplates.clinicalSummary` (trigger `Print`) |

## 7. Nested / follow-on

Same planning / cross-module Continue paths.

## 8. Forms (summary)

Plan summary + pharmacy + finalize override when applicable.

## 9. Print / labels / preview

- Table Print: preview-first `printDischargeWorkspaceList` (`commonPrintActionLabel`)
- Detail print via pending `printSummary` (pending read ∪; trigger `Print`)

## 10. Loading / empty / error / success

Shared Discharge patterns; mutations refresh queue + all visible tab counts.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail / printSummary | `DischargePendingClearanceAtomPermissions.*` → pending read ∪ |
| nextActionPlan / write / pharmacy | clinical write |
| create / update (planning dialog) | Pending atom map (section-scoped) |
| Nested billing / pharmacy / operations / nursing | ∩ as shared clearance gates |
| Export / Print (toolbar) | ∩ `evidence:export` |
