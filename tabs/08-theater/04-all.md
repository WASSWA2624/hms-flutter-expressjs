# Theater tab — All cases

## 1. Tab strip

- Label: `theaterAllCasesSummaryLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `theaterSectionTabCount` → `scopeCounts.all`; active narrowed → filtered page total
- Sibling tabs: dedicated unfiltered `TheaterScopeCounts` (shared chrome)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all` (URL **omits** `section` when this tab is active; unknown query defaults here)
- Tab gate: `TheaterAllAtomPermissions.tab`
- Tab applies: `clearFilters()`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print → Schedule case**

- Same chrome as other case boards
- Date filter: **enabled**
- **Unique:** status + stage filter groups enabled

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail
- Default columns (**5** + optional next-action): Patient, Procedure, Time, Room, Status (+ next-action when write ∩)
- Column choices: Case ID, Readiness, Owner
- Storage: `theater_all` / `theater_cw_all`

## 4. Advanced filters / search fields

- Groups:
  - Status (`theaterStatusFilterLabel`) — `theaterCaseStatuses` choices
  - Stage (`theaterStageFilterLabel`) — `theaterWorkflowStages` choices
- Text fields: room / surgeon / anesthetist IDs
- Date range on schedule date
- Clear filters resets query (via tab apply / filter reset)

## 5. Primary / secondary / row actions

- Strip: Schedule case
- Next-action / Quick Actions: full board mutation set (stage-aware)
- Row select → case detail

## 6. Dialogs from this tab

Same Theater-owned hubs as Scheduled; all `panel=` deep-links reachable when write ∩.

## 7–10. Nested / Forms / Print / Feedback

Shared chrome: gated Export/Print, prefer-5 columns, empty/loading/error/success coverage.
