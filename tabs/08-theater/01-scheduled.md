# Theater tab — Scheduled

## 1. Tab strip

- Label: `theaterScheduledSummaryLabel`
- Icon: `Icons.event_available_outlined`
- Count source: `theaterSectionTabCount` → dedicated `scopeCounts.scheduled` (unfiltered sibling total); active badge uses filtered `cases.totalItemCount` when search/operator filters narrow
- Sibling tabs: dedicated unfiltered `TheaterScopeCounts` (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `scheduled`
- Tab gate: `TheaterScheduledAtomPermissions.tab` = theater board read ∪
- Tab applies: `status=SCHEDULED` (`clearStage: true`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule case**

- Search hint: `theaterSearchHint`
- Clear: `theaterClearFiltersAction`
- Filters: `commonFiltersActionLabel` → `theaterAdvancedFiltersTitle`; Apply `theaterApplyFiltersAction`; Close `commonCloseActionLabel`
- Settings: `commonTableSettings*` / `theaterTableSettingsTitle`
- Export: `commonTableExportActionLabel` — ∩ `evidence:export` (`canExportTheaterWorkspace`); omitted when denied
- Print (toolbar): `commonPrintActionLabel` — preview-first (`printTheaterWorkspaceList`); same export gate; omitted when denied
- Context: Schedule case (`theaterScheduleCaseAction`) — omitted without schedule write ∩
- Date filter: **enabled** — `theaterScheduleDateFilterLabel` (From uses same label; To `opdDateToLabel`)

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail hub (`omitNextActionKind` = resolved next)
- Default columns (**5** + optional next-action):
  1. Patient (`theaterPatientColumnLabel`)
  2. Procedure (`theaterProcedureColumnLabel`)
  3. Time (`theaterTimeColumnLabel`)
  4. Room (`theaterRoomColumnLabel`)
  5. Status (`theaterStatusColumnLabel`)
  6. Next action (`theaterNextActionColumnLabel`) — **only if** write ∩ (`theaterBoardShowsNextActionColumn`)
- Column choices (Settings):
  - Case ID (`theaterCaseIdColumnLabel`)
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
| Schedule / reschedule / stage / resource / checklist / anesthesia / post-op / finalize / cancel | Theater-owned |
| Deep-link `panel=` mutation dialogs | Theater-owned |

## 7. Nested / follow-on

Open IPD / Open Emergency (navigation, no write). Billing holds on schedule form need `billing:read`.

## 8. Forms (summary)

Schedule case form hides tenant/facility/session context; reuses shared patient/encounter/procedure fields.

## 9. Print / Export

Preview-first Print; Export gated ∩ `evidence:export`.

## 10. Feedback

Empty / loading / error-retry / success snackbar / validation on authorized mutations.
