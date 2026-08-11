# IPD tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'IPD'))`; when this tab is active and narrowed → `onNarrowedCountChanged` (`_followUpsNarrowedCount`)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `IpdFollowUpsAtomPermissions.tab` = board read ∪
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

**reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'ipd_follow_ups'`, read/write = IPD follow-up atoms).

Order: **Filters → Settings → Export → Print** (Start admission / Manage beds **omitted** — justified: follow-ups host is callback work, not admission intake)

- Search: `receptionFollowUpsSearchHint`
- Filters: `showAdvancedFilterButton: true` — label `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Date filter: **enabled** (`opdFollowUpDateLabel` / from-to labels)
- Status filter group: `follow_up_status` (`receptionStatusLabel` — pending / completed)
- Settings: common table settings
- Export: gated by `canExportIpdWorkspace` (`ipdWorkspaceExportRequirement` ∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` — preview-first via `printIpdWorkspaceList`; gated by `canPrintIpdWorkspace`; **omitted when unauthorized**
- Start admission / Manage beds: **absent**

## 3. Table

- Row model: `ReceptionFollowUpEntry` (IPD-scoped)
- Row select → Follow-up details (`showReceptionFollowUpDetailDialog`)
- Default columns (5): Patient name, Phone, Status, Follow-up date, Follow-up time
- Optional (Settings): Patient ID, Email, Notes
- No admission next-action / bed board columns

## 4. Advanced filters / search fields

- Same filter model as the table and active tab count (`AppSearchBarFilterValue` + client search)
- Date range on follow-up date
- Status group: pending / completed
- Search via reception follow-ups fields

## 5. Primary / secondary / row actions

- No Start admission / Manage beds
- Row → detail; Reschedule / Mark completed when write ∩ allows; Close footer for read-only

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up details | **reused** Reception |
| Nested reschedule save | **reused** |

## 7. Nested / follow-on

Complete / reschedule only. Hard delete not mounted. Billing panels / admission detail _(n/a)_.

## 8. Forms (summary)

Follow-up reschedule date/time/notes; complete confirmation.

## 9. Print / labels / preview

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when unauthorized
- Export when `canExportIpdWorkspace` allows

## 10. Loading / empty / error / success

- Empty: reception follow-ups empty keys
- Retry: `refreshScopedFollowUps`
- Success after write mutations
- Empty unauthorized workspace: `AppWorkspaceStatePanel.forbidden` (shared chrome)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / detail / Close | `ipdFollowUpsRequirement` (read ∪) |
| Reschedule / Mark completed / Save | `ipdFollowUpsWriteRequirement` (clinical write ∩ + roles/module) |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |
| Start admission / Manage beds / billing panel | absent / _(n/a)_ |
| Route entry | AppRoutes ∪ (includes billing:read for shell) |

## 12. Compliance notes

- Shared chrome Print/Export/Filters/Close + narrowed badge applied; regression coverage in `ipd_follow_ups_permissions_test.dart`
- Residual convention gaps for this tab: **none**
