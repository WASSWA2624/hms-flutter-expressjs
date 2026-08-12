# ICU tab — Beds

## 1. Tab strip

- Label: `icuViewBedBoard`
- Icon: `Icons.bed_outlined`
- Count source: sibling = `state.bedBoard.beds.length`; when Beds is active, badge = `visibleBeds.length` (ward / status / search — same model as the table)
- Sibling tabs: dedicated unfiltered scope totals (`IcuScopeCounts` for patient tabs)
- Count tone: `AppTabCountTone.info`
- Deep-link `section`: `beds`
- Tab gate: `IcuBedBoardAtomPermissions.tab` = `icuWorkspaceReadRequirement`
- **Omitted when unauthorized**
- Loads `loadBedBoard` when empty; preserves ward/status/search on reload
- Strip primary: Manage beds (`ipdBedBoardManageBedsAction`) → `AppRoutes.roomsBeds` when `canManageIcuBedBoard`

## 2. Search / Filters / Settings / Export / Print / context

Order: **Filters → Settings → Export → Print** (unauthorized Export/Print omitted)

- Search: `ipdBedBoardSearchHint` → `IcuWorkspaceController.applyBedSearch` (shared with `visibleBeds` / badge)
- Filters: ward + status groups; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`; no date filter (bed domain)
- Settings: `commonTableSettingsActionLabel` → `commonTableSettingsTitle`; Reset/Apply/Close = Reset columns / Apply columns / Close
- Export: `commonTableExportActionLabel` gated by `canExportIcuWorkspace` (∩ `evidence:export`)
- Print: `commonPrintActionLabel` gated by `canPrintIcuWorkspace`; preview-first `printIcuWorkspaceList`
- Strip context after Print: none (Manage beds is strip **primary**)

## 3. Table / board

- `AppListTable<IcuBed>` (`IcuBedBoardPanel`)
- Default columns (≤5): Bed, Location (ward), Occupant, Status, Next action (Open IPD when occupied + authorized; omitted when navigate denied)
- Column choices: none beyond defaults (all catalog columns are the default set)
- Storage keys: `'icu_bed_board'` / `'icu_bed_board_cw'`
- Cell style: no bold/emphasis in row cells (`tables.mdc`)

## 4. Advanced filters / search fields

- Groups: ward (`ipdWardFilterLabel`) + status (`ipdBedStatusFilterLabel` / AVAILABLE…BLOCKED)
- Search fields: bed label/id, ward, room, occupant name/id, status
- Badge tracks `visibleBeds` while Beds is selected

## 5. Primary / secondary / row actions

- Strip primary: Manage beds → rooms-beds (manage gate)
- Row next-action: Open IPD (occupied beds only) via `IcuBedBoardAtomPermissions.openIpd`
- No stay mutate chrome on this tab

## 6. Dialogs from this tab

| Dialog / handoff | Owner |
| --- | --- |
| Rooms & beds navigation | cross-module `AppRoutes.roomsBeds` |
| Open IPD (occupied) | cross-module `AppRoutes.ipd` |
| Stay mutation dialogs | **not mounted** on Beds (use patient tabs) |

## 7. Nested / follow-on

- Manage beds → Facility rooms-beds
- Open IPD → IPD workspace with admission `id` when present

## 8. Forms (summary)

- Filter selects only on this tab; bed CRUD stays on rooms-beds

## 9. Print / labels / preview

- Table Print: `commonPrintActionLabel` → preview-first `printIcuWorkspaceList` (bed / location / occupant / status)

## 10. Loading / empty / error / success

- Empty: `icuBedNoBedsTitle` / `icuBedNoBedsBody`
- Refreshing: `isRefreshingBeds`
- Workspace load/retry via scaffold; bed reload via `loadBedBoard`

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / Filters / Settings / search | `icuWorkspaceReadRequirement` |
| Export / Print | ∩ `evidence:export` |
| Open IPD | `icuNavigationRequirement` |
| Manage beds | `icuBedBoardManageRequirement` (admin / rooms-beds) |
| Route entry | catalog ∩ `icu:read` + module |
