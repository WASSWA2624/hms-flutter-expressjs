# Theater tab — Recovery

## 1. Tab strip

- Label: `theaterRecoverySectionLabel`
- Icon: `Icons.monitor_heart_outlined`
- Count source: `theaterSectionTabCount` → `scopeCounts.recovery` (POST_OP + PACU_HANDOFF); active narrowed → filtered page total
- Sibling tabs: dedicated unfiltered `TheaterScopeCounts` (shared chrome)
- Count tone: `AppTabCountTone.warning`
- Deep-link `section`: `recovery` (aliases `post-op`, `post_op`, `pacu`)
- Tab gate: `TheaterRecoveryAtomPermissions.tab`
- Tab applies: `stage=POST_OP,PACU_HANDOFF` (`theaterRecoveryStageFilter`, `clearStatus: true`) — list and badge scope aligned
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule case**

- Same chrome as Scheduled / In theater
- Date filter: **enabled**

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail
- Default columns (**5** + optional next-action): Patient, Procedure, Room, Time, Status (+ next-action when write ∩)
- Column choices: Case ID, Readiness, Owner
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

## 8–10. Forms / Print / Feedback

Shared chrome: gated Export/Print, prefer-5 columns, empty/loading/error/success coverage.
