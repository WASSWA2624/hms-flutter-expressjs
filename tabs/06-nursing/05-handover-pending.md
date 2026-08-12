# Nursing tab — Handover pending

## 1. Tab strip

- Label: `nursingScopeHandoverPendingLabel`
- Icon: `Icons.swap_horiz_outlined`
- Count source: `state.scopeCounts.handoverPending` / `state.handoverPendingCount` via `nursingScopeTabCount` (worklist-scoped sibling `NursingScopeCounts`, **not** the global pending-handovers list alone); when this tab is selected and search/advanced filters narrow the list, badge uses filtered `worklist.totalItemCount`
- Sibling tabs: dedicated unfiltered `NursingScopeCounts`
- Count always shown including `0` (never null when zero)
- Count tone: `AppTabCountTone.warning`
- Deep-link `scope`: `handover-pending` (aliases `handover_pending`, `handover`)
- Tab gate: `NursingHandoverPendingAtomPermissions.tab` = `nursingWorkspaceReadRequirement` (∩ `nursing:read` + `inpatient-bed-management`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Shift context** (unauthorized Export/Print/Shift omitted)

- Search: `nursingSearchLabel` / `nursingSearchHint` (clear → `applySearch('')`)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close via reception/common keys
- Export: `commonTableExportActionLabel` gated by `canExportNursingWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintNursingWorkspace`; preview-first `printNursingWorkspaceList`
- Shift context: `nursingShiftContextTitle` when `nursingShiftContextRequirement` (also surfaces pending handovers in dialog)
- No dedicated Handover strip toolbar — justified: tab + next-action + detail + Shift context
- Date filter: **enabled** — `nursingDateFilterLabel` / From / To

## 3. Table

- Row model: `NursingWorkItem` via `NursingWorklistPanel`
- Scope: `NursingQueueScope.handoverPending` (`matchesScope` → `pendingHandoverCount > 0`)
- Row select → `NursingPatientDetailDialog`
- Default columns (~5): patient, **responsible_nurse**, location, status + next_action (Next action **omitted** when clinical write gate fails)
- Responsible nurse cell: **justified synthetic summary** (`nursingResponsibleNurseLabel` → `nursingHandoverPendingSummaryLabel` / `nursingAssignedShiftLabel`) — no assignee API field on `NursingPatientSummary`; documented in helpers + print path
- Column choices (Settings): shared pool beyond defaults
- Storage keys: `'nursing_handoverPending'` / `'nursing_cw_handoverPending'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Shared filters including `handover_status` (PENDING / NONE) + date range
- Active badge reflects filtered membership when narrowed

## 5. Primary / secondary / row actions

- Next-action always Create handover → `NursingHandoverDialog`
- Detail: accept handover (`ClinicalFreeTextActionDialog`), complementary actions

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| `NursingHandoverDialog` | Nursing-owned |
| Accept handover free-text | **reused** clinical |
| Patient detail + complementary | Nursing / **reused** |
| Print summary | Nursing helper → clinical summary |

Deep link `panel=handover` → focused handover when `nursingClinicalWriteRequirement` allows.

## 7. Nested / follow-on

- Billing clearance panel + Open billing (`billingPanel` / `openBilling`)
- nestedRead = billing \| last_office (`nursingNestedCrossModuleReadRequirement`)
- Attachments on handover (pdf/png/jpg/jpeg/doc/docx)
- Open ICU (`RouteAccessCatalog.icuEntry`)
- `panel=` deep links under matching write gates (incl. `transfer`)

## 8. Forms (summary)

- Handover: to-user, notes, optional attachments; cancel / submit
- Accept: free-text clinical dialog
- No tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printNursingWorkspaceList` (responsible_nurse uses same synthetic summary)
- Detail Print: `commonPrintActionLabel` (`Print`) → `showNursingPrintSummary` / `PrintDocumentTemplates.clinicalSummary`

## 10. Loading / empty / error / success

- Shared nursing loading / empty feedback
- Stage success / validation use `nursingClinicalWriteRequirement`
- Mutations refresh worklist + sibling `scopeCounts` (handover contributes to shell `nursingWorkloadCount`)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / detail | `nursingWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| write / nextActionHandover / createHandover / acceptHandover / success / validation / panelDeepLink | `nursingClinicalWriteRequirement` |
| complementaryWrite / addNote / vitals / prescribe / … | `nursingWriteRequirement` |
| billingPanel / openBilling | ∩ `billing:read` + `billing-payments` |
| nestedRead | billing \| last_office |
| medicationsPanel / administerMedication | pharmacy / med administer ∩ |
| openIcu / navigation | `RouteAccessCatalog.icuEntry` |
| shiftContext | shift context req |
| Route entry | catalog ∩ `nursing:read` + module |
