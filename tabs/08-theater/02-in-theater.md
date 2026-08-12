# Theater tab — In theater

## 1. Tab strip

- Label: `theaterInTheaterSummaryLabel`
- Icon: `Icons.meeting_room_outlined`
- Count source: `theaterSectionTabCount` → `scopeCounts.inTheater`; active narrowed → filtered page total
- Sibling tabs: dedicated unfiltered `TheaterScopeCounts` (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `in-theater` (aliases `in_theater`, `intheater`)
- Tab gate: `TheaterInTheaterAtomPermissions.tab`
- Tab applies: `status=IN_PROGRESS` (`clearStage: true`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule case**

- Search / Filters / Settings / Export / Print / Schedule: same as Scheduled (shared chrome)
- Date filter: **enabled** — `theaterScheduleDateFilterLabel`

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail hub
- Default columns (**5** + optional next-action):
  1. Patient (`theaterPatientColumnLabel`)
  2. Procedure (`theaterProcedureColumnLabel`)
  3. Room (`theaterRoomColumnLabel`)
  4. Time (`theaterTimeColumnLabel`)
  5. Status (`theaterStatusColumnLabel`)
  6. Next action — when write ∩
- Column choices: Case ID, Readiness, Owner
- Storage: `theater_inTheater` / `theater_cw_inTheater`

## 4. Advanced filters / search fields

- Groups: **none** (status owned by tab)
- Text fields: room / surgeon / anesthetist IDs
- Date range on schedule date

## 5. Primary / secondary / row actions

- Strip: Schedule case
- Next-action typically anesthesia / post-op / handover / readiness / finalize (stage-aware)
- Row select → case detail

## 6. Dialogs from this tab

Same Theater-owned case detail + mutation dialogs as Scheduled (see shared chrome / Scheduled §6).

## 7. Nested / follow-on

Open IPD/Emergency; schedule reuse; mutation → `theaterSavedMessage`.

## 8–10. Forms / Print / Feedback

Shared chrome: gated Export/Print, prefer-5 columns, empty/loading/error/success coverage.
