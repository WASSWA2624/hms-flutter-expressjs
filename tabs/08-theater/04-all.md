# Theater tab — All cases

## 1. Tab strip

- Label: `theaterAllCasesSummaryLabel`
- Icon: `Icons.inventory_2_outlined`
- Count source: `page.totalItemCount ?? items.length`
- Sibling tabs: page-membership / page-total model (shared chrome)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `all` (URL **omits** `section` when this tab is active; unknown query defaults here)
- Tab gate: `TheaterAllAtomPermissions.tab`
- Tab applies: `clearFilters()`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Schedule case**

- Same chrome as other case boards
- Print (toolbar): **not mounted**
- Date filter: **enabled**
- **Unique:** status + stage filter groups enabled

## 3. Table

- Row model: `TheaterCase`
- Row select → case detail
- Default columns: Patient, Procedure, Time, Status (+ next-action when write ∩)
- Column choices: Case ID, Room, Readiness, Owner
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

## 7. Nested / follow-on

Same Open IPD/Emergency + schedule billing/procedure reuse.

## 8. Forms (summary)

Full Theater mutation form catalog (schedule, stage, start, handover, cancel, resource, checklist, anesthesia, post-op, finalize).

## 9. Print / labels / preview

- Table Print: **absent**

## 10. Loading / empty / error / success

Shared Theater patterns.

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / list / search / filters / settings / detail | `TheaterAllAtomPermissions.*` → board read ∪ |
| Export | ungated |
| Schedule / writes / panels | clinical write ∩ |
| Print | n/a |
