# Theater tab — Scheduled

## 1. Tab strip

- Label: `theaterScheduledSummaryLabel`
- Icon: `Icons.event_available_outlined`
- Count source: `state.scheduledCount` — cases on **current loaded page** with status `SCHEDULED`
- Sibling tabs: page-membership / page-total model (shared chrome); not dedicated unfiltered sibling totals
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `scheduled`
- Tab gate: `TheaterScheduledAtomPermissions.tab` = theater board read ∪
- Tab applies: `status=SCHEDULED` (`clearStage: true`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Schedule case**

- Search hint: `theaterSearchHint`
- Clear: `theaterClearFiltersAction`
- Filters: `theaterFiltersLabel` → `theaterAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`
- Settings: `commonTableSettings*` / `theaterTableSettingsTitle`
- Export: default AppListTable Export — **no** `evidence:export` gate
- Print (toolbar): **not mounted**
- Context: Schedule case (`theaterScheduleCaseAction`) — omitted without schedule write ∩
- Date filter: **enabled** — `theaterScheduleDateFilterLabel` (From uses same label; To `opdDateToLabel`)

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail hub (`omitNextActionKind` = resolved next)
- Default columns (**4** + optional next-action):
  1. Patient (`theaterPatientColumnLabel`)
  2. Procedure (`theaterProcedureColumnLabel`)
  3. Time (`theaterTimeColumnLabel`)
  4. Status (`theaterStatusColumnLabel`)
  5. Next action (`theaterNextActionColumnLabel`) — **only if** write ∩ (`theaterBoardShowsNextActionColumn`)
- Column choices (Settings):
  - Case ID (`theaterCaseIdColumnLabel`)
  - Room (`theaterRoomColumnLabel`)
  - Readiness (`theaterReadinessColumnLabel`)
  - Owner / responsible (`theaterResponsibleRoleColumnLabel`)
- Storage: `theater_scheduled` / `theater_cw_scheduled`

## 4. Advanced filters / search fields

- Groups: **none** on this tab (status owned by tab; status/stage groups only on All)
- Text fields: room ID (`theaterRoomIdLabel`), surgeon ID (`theaterSurgeonIdLabel`), anesthetist ID (`theaterAnesthetistIdLabel`)
- Date range on schedule date

## 5. Primary / secondary / row actions

- Strip: Schedule case
- Next-action / Quick Actions (write): Update readiness, Start case, stage/handover/cancel/resource/anesthesia/post-op/finalize per `theater_next_action` resolution
- Row select → case detail (primary next omitted from hub when already in next-action column)

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Case detail | Theater-owned |
| Schedule / reschedule (`showTheaterScheduleCaseDialog`) | Theater-owned |
| Start case confirm (`AppConfirmActionDialog`) | Theater-owned |
| Stage / handover / cancel / resource / checklist / anesthesia / post-op / finalize forms | Theater-owned |
| Deep-link panel dialogs | Theater-owned (see shared chrome) |

## 7. Nested / follow-on

From detail / Quick Actions:

1. Open IPD / Open Emergency (source context navigation)
2. Schedule form → **reused** procedure catalog + optional billing panel
3. Mutation forms → repository calls → `theaterSavedMessage`

## 8. Forms (summary)

- Schedule: patient, encounter, emergency case, scheduled at/time, room, surgeon, anesthetist, stage notes, procedures (+ optional billing)
- Stage: stage, status, stage notes
- Start: confirm only
- Handover: destination WARD/ICU/OPD, notes
- Cancel: cancellation reason
- Checklist / anesthesia / post-op / resource / finalize: as shared chrome panel forms

## 9. Print / labels / preview

- Table Print: **absent**
- Detail / mutations: no Theater print path / `PrintDocumentTemplates` wiring

## 10. Loading / empty / error / success

- Loading: `theaterLoadingTitle` / `theaterLoadingBody`
- Empty: `theaterNoCasesTitle` / `theaterNoCasesBody`
- Error: snackbars via `showAppFailureSnackBar`
- Success: `theaterSavedMessage`
- After mutations: refresh table rows and visible tab counts

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list chrome / search / filters / settings / empty / loading / retry / detail | `TheaterScheduledAtomPermissions.*` → board read ∪ |
| Export | ungated (default Export) |
| Schedule case / next-action / detail writes / panel mutations | clinical write ∩ (`theaterClinicalWriteRequirement` / section write) |
| Billing holds on schedule | ∩ `billing:read` + `billing-payments` |
| Open IPD / Emergency | navigation requirement (empty / permissive) |
| Print | n/a (not mounted) |
