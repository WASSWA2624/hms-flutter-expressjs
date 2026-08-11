# IPD tab — Transfers

## 1. Tab strip

- Label: `ipdTransfersTabLabel`
- Icon: `Icons.swap_horiz`
- Count source: sibling `summaryCounts` / `state.transferPendingCount`; when this tab is active and search/advanced filters narrow the queue → `admissions.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `transfers` (aliases `transfer-pending`, `transfer_pending`, `transferpending`)
- Tab gate: `IpdTransfersAtomPermissions.tab`
- **Omitted when unauthorized**
- Scope: `IpdQueueScope.transferPending`

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start admission**

- Filters label: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Export: `commonTableExportActionLabel` — gated by `ipdWorkspaceExportRequirement` / `canExportIpdWorkspace` (∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` → `Print` — gated by `canPrintIpdWorkspace`; preview-first via `printIpdWorkspaceList` / `PrintDocumentTemplates.registry`; **omitted when unauthorized**
- Start admission when allowed (after Print)
- Manage beds not mounted

## 3. Table

- Row model: transfer-pending `IpdAdmissionSummary`
- Row select → admission detail (`ipdAdmissionDetailTitle` — generic)
- Default columns (**5** when next-action shown): Patient name, Ward and bed, Admitted, Status, Next action
  - Always-visible: Patient, Status, Next action
- Column choices (Settings): Role, Length of stay — Reset/Apply use reception column keys
- Next action commonly Manage / Request transfer

## 4. Advanced filters / search fields

Same `IpdAdmissionQuery` model as table + active badge.

- Search fields / text filters: shared IPD set
- Groups: Ward; Transfer status (included); Has active bed; Critical alert/severity; ICU queue/status
- Date range on admitted-at (`ipdAdmittedAtColumnLabel`)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Start admission when allowed (after Print)
- Next action: Manage transfer / Request transfer (operational) plus other stage kinds
- Row → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned (`AppDialog`, maximized default) |
| Transfer request | IPD-owned `showIpdTransferRequestDialog` |
| Transfer update | IPD-owned `showIpdTransferUpdateDialog` |
| Start admission | IPD-owned (`ClinicalAdmissionActionDialog`, maximized + pinned footer) |

## 7. Nested / follow-on

Detail complementary writes + `panel=transfer` deep link (operational). Billing panel when authorized. Clinical notes/orders when clinical write. No nested feature routes for desk tasks.

## 8. Forms (summary)

Transfer from/to ward/bed/status; start admission; nursing/discharge/clinical as opened from detail. Tenant/facility/session context not re-prompted.

## 9. Print / labels / preview

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when unauthorized

## 10. Loading / empty / error / success

Shared IPD queue feedback; `_showSaved` after transfer mutations. Empty unauthorized workspace: `AppWorkspaceStatePanel.forbidden` (shared chrome).

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Manage / Request transfer / Start admission | operational write ∪ |
| Nursing / Discharge / orders | clinical write ∩ |
| Billing panel / Open billing | ∩ `billing:read` |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |
| Manage beds | not mounted |
| `panel=transfer` | operational write ∪ |

## Compliance notes

Remediated under `prompts/04-ipd/03-transfers.md` (+ shared chrome). Regression coverage in `ipd_transfers_permissions_test.dart`: omit Export/Print, five default columns + Settings, Advanced filters Close, Print preview, filtered active badge, `warning` tone.
