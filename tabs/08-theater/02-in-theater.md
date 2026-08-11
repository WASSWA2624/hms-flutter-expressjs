# Theater tab — In theater

## 1. Tab strip

- Label: `theaterInTheaterSummaryLabel`
- Icon: `Icons.meeting_room_outlined`
- Count source: `state.inTheaterCount` — current page membership with status `IN_PROGRESS`
- Sibling tabs: page-membership / page-total model (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `in-theater` (aliases `in_theater`, `intheater`)
- Tab gate: `TheaterInTheaterAtomPermissions.tab`
- Tab applies: `status=IN_PROGRESS` (`clearStage: true`)
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Schedule case**

- Search / Filters / Settings / Export / Schedule: same as Scheduled (shared chrome)
- Print (toolbar): **not mounted**
- Date filter: **enabled** — `theaterScheduleDateFilterLabel`

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail hub
- Default columns:
  1. Patient (`theaterPatientColumnLabel`)
  2. Procedure (`theaterProcedureColumnLabel`)
  3. Room (`theaterRoomColumnLabel`)
  4. Status (`theaterStatusColumnLabel`)
  5. Next action — when write ∩
- Column choices: Case ID, Time, Readiness, Owner
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

Same chain: Open IPD/Emergency; schedule form billing/procedure reuse; mutation snackbars.

## 8. Forms (summary)

Same Theater-owned mutation form set as Scheduled.

## 9. Print / labels / preview

- Table Print: **absent**
- No Theater-owned label/print path on this tab

## 10. Loading / empty / error / success

Shared Theater loading / empty / snackbar patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail | `TheaterInTheaterAtomPermissions.*` → board read ∪ |
| Export | ungated |
| Schedule / next-action / writes / panels | clinical write ∩ |
| Billing holds | billing read ∩ |
| Print | n/a |
