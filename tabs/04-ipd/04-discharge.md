# IPD tab — Discharge planned

## 1. Tab strip

- Label: `ipdDischargeTabLabel`
- Icon: `Icons.fact_check_outlined`
- Count source: sibling `summaryCounts` / `state.dischargePlannedCount`; when this tab is active and search/advanced filters narrow the queue → `admissions.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `discharge` (aliases `discharge-planned`, `discharge_planned`, `dischargeplanned`)
- Tab gate: `IpdDischargeAtomPermissions.tab`
- **Omitted when unauthorized**
- Scope: `IpdQueueScope.dischargePlanned`

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start admission**

- Filters label: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Export: `commonTableExportActionLabel` — gated by `ipdWorkspaceExportRequirement` / `canExportIpdWorkspace` (∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` → `Print` — gated by `canPrintIpdWorkspace`; preview-first via `printIpdWorkspaceList` / `PrintDocumentTemplates.registry`; **omitted when unauthorized**
- Start admission when operational write allows (after Print)
- Manage beds not mounted

## 3. Table

- Row model: discharge-planned `IpdAdmissionSummary`
- Row select → admission detail (`ipdAdmissionDetailTitle` — generic)
- Default columns (**5** when next-action shown): Patient name, Ward and bed, Admitted, Status, Next action
  - Always-visible: Patient, Status, Next action
- Column choices (Settings): Role, Length of stay — Reset/Apply use reception column keys
- Next action often Plan/Manage discharge

## 4. Advanced filters / search fields

Same `IpdAdmissionQuery` model as table + active badge.

- Search fields / text filters: shared IPD set
- Groups: Ward; Has active bed; Critical alert/severity; ICU queue/status
- Transfer-status group **not** added for Discharge (only admission queue / active / transfers)
- Date range on admitted-at (`ipdAdmittedAtColumnLabel`)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Start admission when operational write allows (after Print)
- Next action: plan/manage discharge (clinical), plus other kinds if stage maps
- Detail: Release bed when discharge planned + active bed (operational)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned (`AppDialog`, maximized default) |
| Discharge planning / manage | **reused** discharge feature dialogs |
| Release bed | **reused** shared ipd release-bed |
| Start admission | IPD-owned (`ClinicalAdmissionActionDialog`, maximized + pinned footer) |

## 7. Nested / follow-on

`panel=discharge` → clinical write. Open billing for final bill / outstanding (billing read; never cashier). Insurance/billing panels when authorized. No nested feature routes for desk tasks.

## 8. Forms (summary)

Discharge plan fields; release bed confirm; start admission; clinical orders from detail. Tenant/facility/session context not re-prompted.

## 9. Print / labels / preview

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when unauthorized

## 10. Loading / empty / error / success

Shared IPD queue feedback. Empty unauthorized workspace: `AppWorkspaceStatePanel.forbidden` (shared chrome).

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Plan/Manage discharge / nursing | clinical write ∩ |
| Start admission / Release bed / transfers | operational write ∪ |
| Open billing / billing panel | ∩ `billing:read` |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |
| `panel=discharge` | clinical write ∩ |
| Manage beds | not mounted |

## Compliance notes

Remediated under `prompts/04-ipd/04-discharge.md` (+ shared chrome). Regression coverage in `ipd_discharge_permissions_test.dart`: omit Export/Print, five default columns + Settings, Advanced filters Close, Print preview, filtered active badge, `warning` tone.
