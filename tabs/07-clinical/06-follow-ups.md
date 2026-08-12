# Clinical tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle` → **Follow-ups**
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope())`; when this tab is active and Filters/search/date narrow the list, badge uses `onNarrowedCountChanged`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `ClinicalFollowUpsAtomPermissions.tab` = `clinicalFollowUpsRequirement` (= `clinicalWorkspaceReadRequirement`)
- **Omitted when unauthorized** (AccessGate → shrink; no disabled placeholder)

## 2. Search / Filters / Settings / Export / Print / context

Hosted by **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: 'clinical_follow_ups'`):

Order: **Filters → Settings → Export → Print**

- Search: shared follow-up search / Clear reception clear label
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`
- Date filter: **enabled** — `opdFollowUpDateLabel` (From/To)
- Status group: `follow_up_status` (pending / completed)
- Settings: `commonTableSettings*` (Reset reception column key; Close `commonCloseActionLabel`)
- Export / Print: gated by ∩ `evidence:export` (`canExportClinicalWorkspace` / `canPrintClinicalWorkspace`); Print label `commonPrintActionLabel` (`Print`); preview-first via `_printClinicalFollowUpsList`
- Create: **not** mounted on Clinical host
- Requirements override: `clinicalFollowUpsRequirement` / `clinicalFollowUpsWriteRequirement` (not Reception defaults)

## 3. Table

- Panel: **reused** `FollowUpWorklistPanel`
- Row model: `ReceptionFollowUpEntry` (unscoped / all encounter types)
- Row select → **reused** `showReceptionFollowUpDetailDialog` (clinical RW gates)
- **Default columns (5):** patient (`opdPatientNameLabel`), phone, status, date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- Always-visible: patient
- Column choices (Settings): patient id, email, notes (+ defaults)
- Storage: `clinical_follow_ups_cols` / `clinical_follow_ups_cw` (via `clinical_follow_ups` prefix)

## 4. Advanced filters / search fields

- Same filter model as table + active Follow-ups badge (shared panel narrowing)
- Status group + scheduled date range (mounted by Clinical host)
- Footer: **Clear filters** → **Apply filters** → **Close**

## 5. Primary / secondary / row actions

- Detail: Reschedule / Mark completed / Save / Close (write-gated; Close remains for read)
- Titles: `clinicalFollowUpDetailsTitle` / Reception follow-up copy where reused
- No Create / no encounter clinical action bar from this tab

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** Reception (`showReceptionFollowUpDetailDialog`; clinical RW override) |
| Nested reschedule / complete | **reused** Reception / shared follow-up save |

Flows stay in-desk (no nested feature routes).

## 7. Nested / follow-on

- Nested reschedule / complete only
- Hard delete/void **not** mounted
- Billing / admission / encounter clinical actions **not** reachable from this tab

## 8. Forms (summary)

Shared Reception follow-up reschedule / complete fields (hide tenant/facility/session context).

## 9. Print / labels / preview

- Table Print: present after Export when export gate allows; preview-first
- Trigger label: `Print`
- Detail dialogs: no separate print surface

## 10. Loading / empty / error / success

- Empty: `receptionFollowUpsEmptyTitle` / Body
- Error/retry via panel + scoped refresh
- Success after complete/reschedule (write-gated)
- Mutations refresh list + Follow-ups badge (authoritative / narrowed)

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / pagination / empty / loading / retry / rowSelect / detail / close / nestedRead | `clinicalFollowUpsRequirement` |
| export / listPrint | `clinicalWorkspaceExportRequirement` (∩ `evidence:export`) |
| success / validation / create/update/delete/write / reschedule / markCompleted / saveFollowUp | `clinicalFollowUpsWriteRequirement` |
| entry / routeEntry | catalog entry (`clinical:read`) |
| Encounter clinical writes / lab / radiology / pharmacy / admission | **n/a** on this tab |
