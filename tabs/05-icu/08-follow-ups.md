# ICU tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: sibling = `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'ICU'))` (scheduled entry length); when Follow-ups is active and search/advanced filters narrow the list, badge = visible membership via `onNarrowedCountChanged` (same filter/search model as the table)
- Sibling tabs: dedicated unfiltered scope totals (`IcuScopeCounts` for patient tabs; beds uses bed board)
- Count tone: `AppTabCountTone.warning` (attention queue; not `info`)
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `IcuFollowUpsAtomPermissions.tab` = `icuFollowUpsRequirement` (= read ∪)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

- Search hint: `receptionFollowUpsSearchHint` (client filter on name / id / phone / email / notes / status)
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close = Reset columns / Apply columns / Close
- Export: default `Export` label gated by `canExportIcuWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintIcuWorkspace`; preview-first `_printIcuFollowUpsList` → `printIcuWorkspaceList`
- Context strip actions: **none**
- Date filter: scheduled follow-up date (`opdFollowUpDateLabel` / from–to)

## 3. Table

- Panel: **reused** `FollowUpWorklistPanel` (`encounterType: 'ICU'`)
- Row model: `ReceptionFollowUpEntry`
- Row select → Reception-owned follow-up detail (`showReceptionFollowUpDetailDialog`)
- Default columns (≤5): Patient, Phone, Status, Date, Time
- Column choices (Settings): patient_id, email, notes (plus defaults)
- Storage keys: `'icu_follow_ups_cols'` / `'icu_follow_ups_cw'` (`storageKeyPrefix: 'icu_follow_ups'`)
- Cell style: plain `Text` / `AppListItemText` (no bold/emphasis in row cells)

## 4. Advanced filters / search fields

- Groups: status (`follow_up_status` → pending / completed) + date range on `scheduledAt`
- Search + advanced filters share the same membership used for the active badge
- Domain matches OPD/IPD Follow-ups hosts (status + scheduled date; free-text search covers contact/notes)

## 5. Primary / secondary / row actions

- Strip context: none
- No row next-action column
- Row select → follow-up detail hub

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail (`clinicalFollowUpDetailsTitle` / `opdFollowUpsTitle`) | **reused** Reception `reception_follow_up_detail_dialog.dart` |
| Mark completed | **reused** Reception (write ∪) |
| Reschedule / save follow-up | **reused** Reception forms (write ∪) |

## 7. Nested / follow-on

- Complete / reschedule stay in-desk via shared dialogs (no nested feature routes)
- Mutations refresh scoped follow-ups + tab count provider

## 8. Forms (summary)

- Shared Reception follow-up reschedule fields/validators; no tenant/facility/session fields on operator forms

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList` (patient / phone / status / date / time + optional id / email / notes)
- Detail Print: not mounted on this tab’s detail hub (Reception complete/reschedule chrome)

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / `receptionFollowUpsEmptyBody`
- Loading: panel `CircularProgressIndicator`
- Error/retry: `AppStateView` + `commonRetryActionLabel` → `refreshScopedFollowUps`
- Mutations: complete / reschedule refresh list + counts; write-gated success/validation feedback

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / Filters / Settings / search / row select / detail / close | `icuFollowUpsRequirement` (read ∪) |
| Export / Print | ∩ `evidence:export` (`IcuFollowUpsAtomPermissions.export` / `print`) |
| Mark completed / Reschedule / Save | `icuFollowUpsWriteRequirement` (write ∪) |
| Route entry | catalog ∩ `icu:read` + module |
| Hard delete | write ∪ — **not mounted** |
