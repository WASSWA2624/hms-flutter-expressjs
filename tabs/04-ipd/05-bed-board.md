# IPD tab — Bed board

## 1. Tab strip

- Label: `ipdBedBoardTab`
- Icon: `Icons.grid_view_outlined`
- Count source: **none** (`null` — board with no row-total badge; justified product exception — occupancy board is not a queue total)
- Count tone: `AppTabCountTone.info` (applies if a count is ever introduced; currently unused while count is null)
- Deep-link `section`: `bed-board` (aliases `beds`, `bed_board`, `bedboard`)
- Tab gate: `IpdBedBoardAtomPermissions.tab`
- **Omitted when unauthorized**
- Strip primary: Manage beds (`ipdBedBoardManageBedsAction`) → `AppRoutes.roomsBeds` — **omitted when unauthorized** (`ipdBedManageRequirement`)

## 2. Search / Filters / Settings / Export / Print / context

Hosted by IPD-owned `IpdBedBoardPanel` (own `AppListTable<IpdBedBoardEntry>`).

Order: **Filters → Settings → Export → Print → Start admission**

- Search: `ipdBedBoardSearchHint` / `ipdBedBoardSearchLabel`
- Filters: `commonFiltersActionLabel` → `commonAdvancedFiltersTitle`; Apply `opdApplyFiltersAction`; Clear `opdClearFiltersAction`; Close `commonCloseActionLabel`; date filter **disabled**
- Settings: `commonTableSettings*` (storage `ipd_bed_board`)
- Export: `commonTableExportActionLabel` — gated by `ipdWorkspaceExportRequirement` / `canExportIpdWorkspace` (∩ `evidence:export`); **omitted when unauthorized**
- Print: `commonPrintActionLabel` — preview-first via `printIpdWorkspaceList` / `PrintDocumentTemplates.registry`; gated by `canPrintIpdWorkspace`; **omitted when unauthorized**
- Context: Start admission on search trailing when operational write allows

## 3. Table / board

- Row model: `IpdBedBoardEntry` from `state.bedBoard`
- Row select: opens admission detail when occupant admission id present
- Default columns (5): Bed, Ward, Room, Current patient, Status — plus Next action when `canManageBeds` (manage-gated, always-visible when shown)
- Optional columns: **none** (full available set is the default + manage next-action)
- Next actions (manage gate): Reserve / Block / Cleaning / Available / Open admission (status-dependent via `_bedActionsFor`)

## 4. Advanced filters / search fields

- Groups: Ward (`ipdWardFilterLabel`), Bed status (`ipdBedStatusFilterLabel`)
- No admitted-at date filter
- Client search via `bed.matchesSearch`
- Same filter model as table (`bedBoardWardId` / `bedBoardStatus`); active tab has no count badge to update

## 5. Primary / secondary / row actions

- Strip: Manage beds
- Search bar: Start admission (after Print)
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

- Table Print: present — `commonPrintActionLabel`, preview-first (`printIpdWorkspaceList`); omitted when unauthorized
- Export Excel when `canExportIpdWorkspace` allows

## 10. Loading / empty / error / success

- Loading: `state.isLoadingBedBoard`
- Empty: `ipdBedBoardEmptyTitle` / `ipdBedBoardEmptyBody`
- Failures: `_showFailure` after ward/status/bed updates
- Success: `_showSaved` after start admission
- Empty unauthorized workspace: `AppWorkspaceStatePanel.forbidden` (shared chrome)

## 11. RBAC / ABAC

| Atom | Gate |
| --- | --- |
| Tab / chrome / row select detail | board read ∪ |
| Start admission | operational write ∪ |
| Bed status next-actions / Manage beds | `ipdBedManageRequirement` (admin ∪; no `unit:manage`) |
| Nested billing in detail | ∩ `billing:read` |
| Export / Print | `ipdWorkspaceExportRequirement` (∩ `evidence:export`) |

## 12. Compliance notes

- Shared chrome Print/Export/Filters labels applied; regression coverage in `ipd_bed_board_permissions_test.dart`
- Residual convention gaps for this tab: **none**
