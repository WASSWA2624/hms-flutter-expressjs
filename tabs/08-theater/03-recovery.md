# Theater tab — Recovery

## 1. Tab strip

- Label: `theaterRecoverySectionLabel`
- Icon: `Icons.monitor_heart_outlined`
- Count source: `state.recoveryCount` — current page membership with status/stage `POST_OP` **or** `PACU_HANDOFF`
- Sibling tabs: page-membership / page-total model (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `recovery` (aliases `post-op`, `post_op`, `pacu`)
- Tab gate: `TheaterRecoveryAtomPermissions.tab`
- Tab applies: `stage=POST_OP` (`clearStatus: true`) — **list filter is POST_OP only**; badge may still count PACU_HANDOFF on page
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Schedule case**

- Same chrome as Scheduled / In theater
- Print (toolbar): **not mounted**
- Date filter: **enabled**

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail
- Default columns: Patient, Procedure, Room, Status (+ next-action when write ∩) — same as In theater
- Column choices: Case ID, Time, Readiness, Owner
- Storage: `theater_recovery` / `theater_cw_recovery`

## 4. Advanced filters / search fields

- Groups: **none** (stage owned by tab)
- Text: room / surgeon / anesthetist IDs
- Date range on schedule date

## 5. Primary / secondary / row actions

- Strip: Schedule case
- Next-action / Quick Actions: handover / finalize / post-op / resource / cancel as stage allows
- Row select → case detail

## 6. Dialogs from this tab

Theater-owned detail + mutation dialogs (shared catalog). Deep-link `panel=postop` common for this section.

## 7. Nested / follow-on

Open IPD/Emergency; schedule reuse; mutation → `theaterSavedMessage`.

## 8. Forms (summary)

Same Theater-owned form set; handover destination + finalize record type especially relevant here.

## 9. Print / labels / preview

- Table Print: **absent**

## 10. Loading / empty / error / success

Shared Theater patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail | `TheaterRecoveryAtomPermissions.*` → board read ∪ |
| Export | ungated |
| Schedule / writes / panels | clinical write ∩ |
| Print | n/a |
