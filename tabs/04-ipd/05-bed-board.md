# IPD tab — Bed board

## 1. Tab strip

- Label: `ipdBedBoardTab`
- Icon: `Icons.grid_view_outlined`
- Count source: **none** (`null` — board with no row-total badge)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `bed-board` (aliases `beds`, …)
- Tab gate: `IpdBedBoardAtomPermissions.tab`
- **Omitted when unauthorized**
- Strip primary: Manage beds (`ipdBedBoardManageBedsAction`) → `AppRoutes.roomsBeds` — **omitted when unauthorized** (`ipdBedManageRequirement`)

## 2. Search / Filters / Settings / Export / Print / context

Hosted by IPD-owned `IpdBedBoardPanel` (own `AppListTable<IpdBedBoardEntry>`):

- Search: `ipdBedBoardSearchHint` / `ipdBedBoardSearchLabel`
- Filters: `ipdFiltersLabel` → Advanced filters; date filter **disabled**
- Settings: `commonTableSettings*` (storage `ipd_bed_board`)
- Export: enabled (`ipd_bed_board` stem)
- Print (toolbar): **absent**
- Context: Start admission on search trailing when operational write allows

## 3. Table / board

- Row model: `IpdBedBoardEntry` from `state.bedBoard`
- Row select: opens admission detail when occupant admission id present
- Default columns (from panel helpers): Bed label, Occupant, Ward/room location, Status, Next action (bed status menu when `canManageBeds`)
- Optional columns: panel-defined extras (room/ward metadata as coded in `_ipdBedBoardOptionalColumns`)
- Next actions (manage gate): Reserve / Block / Cleaning / Available / Open admission (status-dependent via `_bedActionsFor`)

## 4. Advanced filters / search fields

- Groups: Ward (`ipdWardFilterLabel`), Bed status (`ipdBedStatusFilterLabel`)
- No admitted-at date filter
- Client search via `bed.matchesSearch`

## 5. Primary / secondary / row actions

- Strip: Manage beds
- Search bar: Start admission
- Next-action / menu: bed status updates (`controller.updateBedStatus`) when manage allowed
- Occupied row → admission detail

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Start admission | IPD-owned |
| Admission detail (occupied) | IPD-owned `_IpdDetailPanel` |
| Rooms-beds navigation | route go (not a dialog) |

## 7. Nested / follow-on

From admission detail: same complementary writes / billing panels / clinical as other tabs. `panel=` / `action=` deep links from board use operational write for beds/transfer focus.

## 8. Forms (summary)

Start admission fields; bed status mutations are direct controller updates (no separate form dialog beyond confirms if any).

## 9. Print / labels / preview

- Table Print: **absent**
- Export Excel present

## 10. Loading / empty / error / success

- Loading: `state.isLoadingBedBoard`
- Empty: `ipdBedBoardEmptyTitle` / `ipdBedBoardEmptyBody`
- Failures: `_showFailure` after ward/status/bed updates
- Success: `_showSaved` after start admission

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select detail | board read ∪ |
| Start admission | operational write ∪ |
| Bed status next-actions / Manage beds | `ipdBedManageRequirement` (admin ∪; no `unit:manage`) |
| Nested billing in detail | ∩ `billing:read` |
| Export | mounted (no evidence:export atom) |
