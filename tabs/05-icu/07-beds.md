# ICU tab — Beds

## 1. Tab strip

- Label: `icuViewBedBoard`
- Icon: `Icons.bed_outlined`
- Count source: `state.bedBoard.beds.length`
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `beds`
- Tab gate: `IcuBedBoardAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**
- Loads `loadBedBoard` when empty

## 2. Search / Filters / Settings / Export / Print / context

- **No** `AppListTable` search / Filters / Settings / Export / Print
- Strip primary: Manage beds (`ipdBedBoardManageBedsAction`, `Icons.open_in_new`) → `AppRoutes.roomsBeds` when `IcuBedBoardAtomPermissions.manageBeds` / `canManageIcuBedBoard`
- Ward chips: `icuBedBoardAllWards` + ward titles (not Advanced filters dialog)

## 3. Table / board

- Custom list `_IcuBedRow` (`IcuBed`) — not patient board table
- Cells: location, occupant / vacant (`icuBedVacantLabel`), status badge
- Summary chips: `icuBedAvailableLabel` / `icuBedOccupiedLabel`
- Occupied row → Open IPD (`icuActionOpenIpd`) with `AppRoutes.ipd?id=admissionId`

## 4. Advanced filters / search fields

- Ward `ChoiceChips` only; no Advanced filters / date

## 5. Primary / secondary / row actions

- Open IPD (occupied)
- Manage beds (strip) → rooms-beds admin

## 6. Dialogs from this tab

| Dialog | Owner |
| --- | --- |
| Stay mutation dialogs | **not opened from this tab** |
| Rooms & beds navigation | cross-module route |

## 7. Nested / follow-on

- Rooms & beds admin surface only

## 8. Forms (summary)

- N/A on this tab

## 9. Print / labels / preview

- **Absent** on bed board

## 10. Loading / empty / error / success

- Loading: `LinearProgressIndicator` when `isRefreshingBeds && beds.isEmpty`
- Empty: `icuBedNoBedsTitle` / `icuBedNoBedsBody`
- Error / success: scaffold / snackbars via shared ICU helpers when applicable

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / listChrome / wardFilters / summaryChips / empty / loading / retry / rowSelect / detail / nestedRead | read |
| openIpd / navigate | `icuNavigationRequirement` |
| manageBeds / nestedWrite | `icuBedBoardManageRequirement` |
| create / update / delete / write | write (not mounted on bed-board UI) |
