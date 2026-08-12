# Theater tab — Follow-ups

## 1. Tab strip

- Label: `opdFollowUpsTitle`
- Icon: `Icons.phone_callback_outlined`
- Count source: `followUpTabCountProvider(FollowUpWorklistScope(encounterType: 'THEATRE'))`; active narrowed count via `onNarrowedCountChanged`
- Sibling tabs: board uses dedicated `TheaterScopeCounts`; this tab uses follow-up provider
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `follow-ups` (aliases `follow_ups`, `followups`)
- Tab gate: `TheaterFollowUpsAtomPermissions.tab`
- Host: **reused** `FollowUpWorklistPanel` (`storageKeyPrefix: theater_follow_ups`, Theater read/write overrides)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (no Schedule case)

- Search hint: `receptionFollowUpsSearchHint`
- Clear: `receptionClearFiltersAction`
- Filters: **on** — `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `theaterApplyFiltersAction`; Close `commonCloseActionLabel`
- Date filter: **on** — `opdFollowUpDateLabel` / From-To OPD keys
- Status filter group: pending / completed
- Settings: `commonTableSettings*` + Apply/Reset column actions
- Export: gated ∩ `evidence:export` (`canExportTheaterWorkspace`)
- Print: `commonPrintActionLabel` — preview-first via `printTheaterWorkspaceList`; same export gate
- Schedule case: **not mounted** on this tab

## 3. Table

- Row model: `ReceptionFollowUpEntry`
- Row select → **reused** follow-up detail
- Default columns (**5**): patient (`opdPatientNameLabel`), phone (`patientsPhoneIdentifierColumnLabel`), status (`receptionStatusLabel`), date (`opdFollowUpDateLabel`), time (`opdFollowUpTimeLabel`)
- Column choices: patient_id, email, notes
- No Theater next-action column (`theaterBoardShowsNextActionColumn` false for follow-ups)
- Storage: `theater_follow_ups_cols` / `theater_follow_ups_cw`

## 4. Advanced filters / search fields

- Advanced filters enabled by Theater host
- Date + status group + panel search (Reception follow-up matcher)

## 5. Primary / secondary / row actions

- Strip: none Theater-specific
- Row: open detail; mutations inside detail when write ∩

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Follow-up detail | **reused** `showReceptionFollowUpDetailDialog` |

## 7. Nested / follow-on

From detail when write ∩:

1. Mark completed (`receptionMarkFollowUpCompletedAction`)
2. Schedule another / reschedule (`receptionScheduleAnotherFollowUpAction`) → clinical follow-up save (`opdSaveFollowUpAction`)
3. Read-only: Close (`commonCloseActionLabel`)

No hard-delete control.

## 8–10. Forms / Print / Feedback

Shared panel forms; gated Export/Print; empty/loading/error/success via FollowUpWorklistPanel.
