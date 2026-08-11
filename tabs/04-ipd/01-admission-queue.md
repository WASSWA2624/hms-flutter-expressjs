# IPD tab — Admission queue

## 1. Tab strip

- Label: `ipdAdmissionQueueTabLabel`
- Icon: `Icons.bed_outlined`
- Count source: sibling `summaryCounts` / `state.admissionQueueCount`; when this tab is active and search/advanced filters narrow the queue → `admissions.totalItemCount`
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `admission-queue` (aliases `admission_queue`, `admissionqueue`, `queue`)
- Tab gate: `IpdAdmissionQueueAtomPermissions.tab`
- **Omitted when unauthorized**
- Default section when unspecified

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start admission**

- Filters label: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Export: `commonTableExportActionLabel` — gated by `ipdWorkspaceExportRequirement` / `canExportIpdWorkspace` (∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` → `Print` — gated by `canPrintIpdWorkspace` (same export atom); preview-first via `printIpdWorkspaceList` / `PrintDocumentTemplates.registry`; **omitted when unauthorized**
- Start admission: `ipdStartAdmissionAction` — omitted without `IpdAdmissionQueueAtomPermissions.startAdmission`
- Manage beds: **not** mounted as strip primary on this tab

## 3. Table

- Row model: `IpdAdmissionSummary` (`IpdQueueScope.admissionQueue`)
- Row select → admission detail dialog (`ipdAdmissionDetailTitle` — generic)
- Default columns (**5** when next-action shown): Patient name, Ward and bed, Admitted, Status, Next action
  - Always-visible: Patient, Status, Next action
- Column choices (Settings): Role, Length of stay — Reset/Apply use reception column keys
- Next-action column mounts for readers (`ipdBoardShowsNextActionColumn`); write buttons hide via gates
- Mobile: title, admission id caption, location + status meta

## 4. Advanced filters / search fields

Same filter model as table query + active badge (`IpdAdmissionQuery` / `applyFilters`).

- Search fields: patient, patient id, admission, encounter, ward, bed, status, transfer, icu
- Text filters: patient id, admission id, encounter id, phone
- Groups: Ward; Transfer status (on this tab); Has active bed; Critical alert; Critical severity; ICU queue/status
- Date range on admitted-at (`ipdAdmittedAtColumnLabel`)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Start admission (search bar, after Print)
- Next action: Approve / Assign bed / Transfer / Nursing note / Discharge / Theatre handover / Continue care (kind from `ipdBoardNextActionKind`)
- Row → detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Admission detail | IPD-owned (`AppDialog`, maximized default) |
| Start admission | IPD-owned (`ClinicalAdmissionActionDialog`, maximized + pinned footer) |
| Assign bed / approve / reject / transfer / nursing / discharge | IPD / **reused** shared |

## 7. Nested / follow-on

Detail Quick Actions + `panel=` / `action=` deep links (beds/transfer/nursing/discharge/…). Billing/insurance panel when ∩ `billing:read`. Navigate ICU/Theater/Nursing/Physio/Billing when eligible. No nested feature routes for desk tasks.

## 8. Forms (summary)

Start admission identity/ward/bed fields; transfer request/update; nursing note; discharge planning; clinical order forms; approve/reject confirms. Tenant/facility/session context not re-prompted.

## 9. Print / labels / preview

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when `canPrintIpdWorkspace` denies
- No IPD-owned chart print on this tab from traced call sites

## 10. Loading / empty / error / success

- Empty: `ipdNoAdmissionsTitle` / `ipdNoAdmissionsBody`
- Success: `_showSaved`
- Loading/retry: scaffold; detail linear progress when refreshing
- Empty unauthorized workspace (no board tabs): `AppWorkspaceStatePanel.forbidden` — see shared chrome

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / Continue care label | board read ∪ |
| Start / Approve / Assign bed / Transfer / Reject | operational write ∪ |
| Nursing / Discharge / clinical orders | clinical write ∩ |
| Billing / insurance panel / Open billing | ∩ `billing:read` (+ module) |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |
| Manage beds | admin bed-manage (not primary here) |
| `panel=` / `action=` | `ipdFocusedMutationRequirement` |

## Compliance notes

Remediated under `prompts/04-ipd/01-admission-queue.md` (+ shared chrome). Regression coverage in `ipd_admission_queue_permissions_test.dart`: omit Export/Print, five default columns + Settings choices, Advanced filters Close footer, Print preview, filtered active badge, warning tone.
