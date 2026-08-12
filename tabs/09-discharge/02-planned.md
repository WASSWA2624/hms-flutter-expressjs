# Discharge tab — Planned

## 1. Tab strip

- Label: `dischargeSectionPlanned`
- Icon: `Icons.event_available_outlined`
- Count source: `DischargeSectionCounts.planned` (catalog); active + search/filters → filtered section membership
- Sibling tabs: dedicated unfiltered `DischargeSectionCounts` sibling-count model
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `planned`
- Tab gate: `DischargePlannedAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print**

- Same queue chrome as All; date filter **on**; strip Plan/Clearance **not mounted** (row next-action; justified)
- Export: ∩ `evidence:export` (`canExportDischargeWorkspace` / Planned export atom)
- Print (toolbar): `commonPrintActionLabel` → `printDischargeWorkspaceList` (same export gate)

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

- Status group (shared list); date filter **on** (`dischargeDateFilterLabel` / From / To)

## 5. Primary / secondary / row actions

- Next-action: Manage clearance (`dischargeManageClearanceAction`) for planned rows (write)
- Row select → detail → Continue into planning/clearance

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Detail | Discharge-owned |
| Planning (`showDischargePlanningDialog` + Planned create/update gates) | Discharge-owned |
| Pharmacy request | Discharge-owned |
| Print clinical summary | **reused** `PrintDocumentTemplates.clinicalSummary` (trigger `Print`) |

## 7. Nested / follow-on

Same cross-module Open\* and finalize/plan paths as All.

## 8. Forms (summary)

Planning clearance + pharmacy request forms (shared).

## 9. Print / labels / preview

- Table Print: preview-first `printDischargeWorkspaceList` (`commonPrintActionLabel`)
- Detail print when summary present (`DischargePlannedAtomPermissions.printSummary`; trigger `Print` / `dischargePrintSummaryAction` → "Print")

## 10. Loading / empty / error / success

Shared Discharge patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail | `DischargePlannedAtomPermissions.*` → workspace read ∪ |
| nextActionClearance / write / pharmacy | clinical write |
| printSummary | read ∪ |
| create / update (planning dialog) | Planned atom map (section-scoped) |
| Billing / pharmacy / operations / nursing panels | nested ∩ as All |
| Export / Print (toolbar) | ∩ `evidence:export` |
