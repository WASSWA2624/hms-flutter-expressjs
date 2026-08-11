# IPD tab — Active patients

## 1. Tab strip

- Label: `ipdActivePatientsTabLabel`
- Icon: `Icons.local_hospital_outlined`
- Count source: sibling `summaryCounts` / `state.activePatientCount`; when this tab is active and search/advanced filters narrow the queue → `admissions.totalItemCount`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `active` (aliases `active-patients`, `active_patients`, `activepatients`)
- Tab gate: `IpdActivePatientsAtomPermissions.tab`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Start admission**

- Filters label: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Export: `commonTableExportActionLabel` — gated by `ipdWorkspaceExportRequirement` / `canExportIpdWorkspace` (∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` → `Print` — gated by `canPrintIpdWorkspace`; preview-first via `printIpdWorkspaceList` / `PrintDocumentTemplates.registry`; **omitted when unauthorized**
- Start admission when operational write allows (after Print)
- Manage beds not mounted

## 3. Table

- Row model: active-scope `IpdAdmissionSummary` (`IpdQueueScope.activePatients`)
- Row select → admission detail (`ipdAdmissionDetailTitle` — generic)
- Default columns (**5** when next-action shown): Patient name, Ward and bed, Admitted, Status, Next action
  - Always-visible: Patient, Status, Next action
- Column choices (Settings): Role, Length of stay — Reset/Apply use reception column keys
- Next-action column mounts for readers; write buttons hide via gates

## 4. Advanced filters / search fields

Same `IpdAdmissionQuery` model as table + active badge.

- Search fields / text filters: shared IPD set
- Groups: Ward; Transfer status (included on Active); Has active bed; Critical alert/severity; ICU queue/status
- Date range on admitted-at (`ipdAdmittedAtColumnLabel`)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Start admission when operational write allows (after Print)
- Next actions: approve/assign/transfer/nursing/discharge/theatre/continue care as stage dictates
- Row → detail (Open billing available in detail when billing read)

## 6. Dialogs from this tab

Same admission detail + mutation dialogs as Admission queue (section atoms from `IpdActivePatientsAtomPermissions`). Maximized defaults + pinned footers on scrollable forms (shared chrome).

## 7. Nested / follow-on

Full detail Quick Actions including clinical orders, ICU start, discharge, transfers, billing navigation. `panel=` deep links per shared chrome. No nested feature routes for desk tasks.

## 8. Forms (summary)

Same admission/transfer/nursing/discharge/clinical forms as Admission queue. Tenant/facility/session context not re-prompted.

## 9. Print / labels / preview

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when unauthorized

## 10. Loading / empty / error / success

Shared IPD queue feedback (`ipdNoAdmissions*`, `_showSaved`, scaffold retry). Empty unauthorized workspace: `AppWorkspaceStatePanel.forbidden` (shared chrome).

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome | board read ∪ |
| Start admission / operational next actions | operational write ∪ |
| Clinical next actions / orders | clinical write ∩ |
| Open billing / billing panel | ∩ `billing:read` |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |
| Manage beds | not mounted |

## Compliance notes

Remediated under `prompts/04-ipd/02-active-patients.md` (+ shared chrome). Regression coverage in `ipd_active_patients_permissions_test.dart`: omit Export/Print, five default columns + Settings, Advanced filters Close, Print preview, filtered active badge, `info` tone.
