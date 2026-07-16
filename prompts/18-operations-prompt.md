# Standardize Operations Tables

## Objective

Refactor every `AppListTable` on the Operations workspace (`/operations`, `OperationsWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

## Compliance Checklist (from prompt.md — per table)

- [ ] Global search matches all columns (including hidden)
- [ ] Search chrome has only Filters (Advanced filters modal) and Settings (Table Settings modal)
- [ ] Session-persisted column visibility via `AppListTableColumnVisibilityController`
- [ ] ≤ 5 declared columns; automatic row number only
- [ ] One semantic field per column; two-line display only for primary/secondary of one field
- [ ] Status + explicit next-action columns when entity has workflow
- [ ] Row tap opens reused detail dialog with follow-up actions
- [ ] Adaptive layout + `mobileItemBuilder` parity
- [ ] Real-time refresh via Riverpod providers

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification. Run tests and formatting after implementation. Treat `prompt.md` as the normative table contract.

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, tab toolbar actions (Create request, Report, Refresh), or unrelated screen chrome unless required for compilation.

**Screen binding:**
- Route: `/operations` (`AppRoutes.operations`)
- Page: `OperationsWorkspacePage` in `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`
- Controller: `operationsWorkspaceControllerProvider` (`OperationsWorkspaceController`)
- Deep-link query keys: `section` / `panel` / `tab`, `search` / `q`, `requestId` / `request_id` / `id`
- Write permission: `AppPermissions.operationsWrite` + active module `facilities-maintenance`

## Current State (from audit)

### Table 1 — `_OperationsQueuePanel`

| Attribute | Value |
|-----------|-------|
| File | `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` |
| Entity | `OperationsWorkItem` |
| Tabs | `allRequests`, `open`, `inProgress`, `completed` (same widget; tab only changes status filter via `_applySectionFilter`) |
| Data source | `state.workItems` via `page:` + `onPageChanged` → `controller.changePage` |
| Detail handler | `onRowSelected` → `_openRequestDetailDialog` (already wired) |
| Storage keys | `columnVisibilityStorageKey: 'operations_${section.name}'`, `columnWidthStorageKey: 'operations_cw_${section.name}'` |

**Current default columns (5 — `_operationColumns`):**

| # | Column id (today) | Label key | Field / builder | Gap |
|---|-------------------|-----------|-----------------|-----|
| 1 | *(missing)* | `operationsRequestColumnLabel` | Issue + `effectiveDisplayId` via `_CopyableSubtitleCell` | Missing `id`; OK as one semantic field |
| 2 | *(missing)* | `operationsAreaColumnLabel` | Category + optional asset via `_CopyableSubtitleCell` / `_TwoLineCell` | Missing `id`; OK as category with asset subtitle |
| 3 | *(missing)* | `operationsPriorityColumnLabel` | `_OperationPriorityBadge` | Should move to `columnChoices` (lower priority vs location for triage) |
| 4 | *(missing)* | `operationsLocationColumnLabel` | `_locationLabel` text | Should move to `columnChoices` |
| 5 | *(missing)* | `operationsStatusColumnLabel` | `_OperationStatusBadge` | Wrong position — must be 4th, not 5th |

**Hidden in `columnChoices` today:** duplicates of all 5 defaults (bug) + assignee, due, next_action (plain `Text` only).

**Search chrome gaps:**
- `matcher: (_, _) => true` — does not match hidden columns client-side (Mortuary uses `_matchesSearch`; copy that pattern)
- `advancedFilterButtonLabel` / `advancedFilterTitle`: both `l10n.operationsFiltersLabel` (`"Filters"`) — modal title must be **Advanced filters**
- `columnVisibilityLabel`: `l10n.commonTableSettingsActionLabel` ✓
- `columnVisibilityTitle`: **not set** — must be **Table Settings**
- No extra trailing chrome in search bar ✓

**Workflow / interaction gaps:**
- No default **next-action** column (required for `OperationsWorkItem` workflow)
- `next_action` only in `columnChoices` as non-interactive `Text`
- `OperationsWorkItem` does **not** use shared `WorkflowActionButton` (facilities module) — use compact `AppButton.secondary` that opens the same dialogs as `_OperationsActionPanel`
- Mobile tile (`_OperationsRequestListTile`) shows next action as `AppInlineMetaText` only — add tappable action parity

**Other:** `displayMode` not set (defaults to `adaptive` ✓). Realtime via `operationsWorkspaceControllerProvider` + `RealtimeEventGroups.operations` ✓.

### Table 2 — `_OperationsAssetsPanel`

| Attribute | Value |
|-----------|-------|
| File | same |
| Entity | `OperationsAsset` |
| Tab | `assets` only |
| Data source | Client-filtered `items:` from `state.assets.items` |
| Detail handler | **Missing** — no `onRowSelected` |
| Storage keys | `operations_assets`, `operations_cw_assets` |

**Current columns (4):**

| # | Column id | Label key | Field / builder |
|---|-----------|-----------|-----------------|
| 1 | `asset_name` | `operationsAssetNameColumnLabel` | Name + `effectiveDisplayId` (`_CopyableSubtitleCell`) |
| 2 | `asset_tag` | `operationsAssetTagColumnLabel` | `assetTag` |
| 3 | `asset_status` | `operationsStatusColumnLabel` | `_OperationStatusBadge` |
| 4 | `asset_location` | `operationsLocationColumnLabel` | `facilityLabel` / `facilityId` |

No workflow — layout within 5-column budget ✓. No next-action column required.

**Gaps:** missing `columnVisibilityTitle`; filter modal title not **Advanced filters**; no row detail dialog; search haystack should include all fields + hidden choice fields if any are added.

### Per-tab matrix

| Tab (`OperationsDeskSection`) | Table widget | Server filter | Column set |
|-------------------------------|--------------|---------------|------------|
| All requests | `_OperationsQueuePanel` | `clearFilters()` | Same 5 defaults |
| Open | `_OperationsQueuePanel` | `applyStatus('OPEN')` | Same |
| In progress | `_OperationsQueuePanel` | `applyStatus('IN_PROGRESS')` | Same |
| Completed | `_OperationsQueuePanel` | `applyStatus('COMPLETED')` | Same |
| Assets | `_OperationsAssetsPanel` | none (local filter) | Same 4 defaults |

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableSearch`, `AppListTableColumn`, `columnVisibilityTitle`, `displayMode`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist`: Filters/Settings chrome, `_matchesSearch` matcher, `columnVisibilityTitle`
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn()` + `WorkflowActionButton` (pattern reference; Operations uses module dialogs instead)
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — `_nextActionColumn` with `WorkflowActionButton` when encounter exists, fallback `Text`
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_OperationsQueuePanel` | allRequests, open, inProgress, completed | `OperationsWorkItem` | request, area, priority, status, next_action | `operations_${section.name}` |
| `_OperationsAssetsPanel` | assets | `OperationsAsset` | asset_name, asset_tag, asset_status, asset_location | `operations_assets` |

### Column plan — `_OperationsQueuePanel` (workflow)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `request` | `operationsRequestColumnLabel` | `metadata.issue` + `effectiveDisplayId` | `_CopyableSubtitleCell` or `AppListItemText`; `alwaysVisible: true` |
| 2 | `area` | `operationsAreaColumnLabel` | `metadata.category` (+ `assetLabel` subtitle when `assetId` set) | Single semantic field |
| 3 | `priority` | `operationsPriorityColumnLabel` | `metadata.priority` | `_OperationPriorityBadge` |
| 4 | `status` | `operationsStatusColumnLabel` | `status` | `_OperationStatusBadge` / `AppWorkspaceStatusBadge` |
| 5 | `next_action` | `operationsNextActionColumnLabel` | `_nextActionLabel(l10n, item)` | `_OperationsNextActionButton` (see below); `alwaysVisible: true` |

**Move to `columnChoices` (hidden by default):** `location` (`_locationLabel`), `assignee` (`metadata.assignee`), `due` (`dueAt` formatted). Do **not** duplicate default columns inside `columnChoices`.

### Column plan — `_OperationsAssetsPanel` (no workflow)

Keep existing 4 columns; optionally add `facility_id` copyable field to `columnChoices` if useful. No status/next-action restructuring needed beyond chrome fixes.

### Next-action mapping (`OperationsWorkItem`)

Use existing `_nextActionLabel` strings and wire `_OperationsNextActionButton` to open the **same** dialogs as `_OperationsActionPanel`:

| `normalizedStatus` | Label key | Action (requires `canMutate` unless noted) |
|--------------------|-----------|---------------------------------------------|
| `OPEN` | `operationsNextActionAssign` | `_showAssignDialog` (after `controller.selectItem(item)`) |
| `IN_PROGRESS` + `assetId` | `operationsNextActionServiceLog` | `_showServiceLogDialog` |
| `IN_PROGRESS` (no asset) | `operationsNextActionUpdateStatus` | `_showStatusDialog` |
| `COMPLETED` | `operationsNextActionCloseout` | `_showNoteDialog` with `_noteKindCloseout` |
| `CANCELLED` | `operationsNextActionCancelled` | Open `_openRequestDetailDialog` (read-only; button disabled or tertiary) |
| other | `operationsNextActionReview` | `_openRequestDetailDialog` |

Implement `_OperationsNextActionButton` as a `ConsumerWidget` using `AppButton.secondary` with `enabled: canMutate && !item.isTerminal` (except COMPLETED closeout and CANCELLED review). Stop event propagation so row selection does not also fire when pressing the button (use `GestureDetector`/`InkWell` with appropriate behavior, or table's action-cell pattern from other modules).

`WorkflowActionButton` is **not** applicable — `OperationsWorkItem` is not a clinical encounter workflow entity.

### Search chrome (both tables)

- **Filters button label:** keep `l10n.operationsFiltersLabel` (`"Filters"`) or add shared `commonFiltersActionLabel` if introduced elsewhere
- **Advanced filters modal title:** `l10n.commonAdvancedFiltersTitle` → **Advanced filters** (add key to `app_en.arb`)
- **Settings button label:** `l10n.commonTableSettingsActionLabel` (`"Settings"`)
- **Table Settings modal title:** `l10n.commonTableSettingsTitle` → **Table Settings** (add key to `app_en.arb`); set `columnVisibilityTitle` on both `AppListTable` instances
- **Queue matcher:** replace `(_, _) => true` with `_operationsWorkItemMatchesSearch(l10n, item, query)` covering: issue, display id, category, asset label/id, priority label, location, facility, status label, assignee, due formatted, next action label
- **Assets matcher:** extend `_assetMatchesSearch` / use same haystack as `_filteredAssets` logic
- Keep `onSubmitted` / server `applySearch` for queue pagination; matcher filters current page rows like Mortuary

### Row interaction

- **Queue:** keep `onRowSelected` → `_openRequestDetailDialog`
- **Assets:** add `onRowSelected` → new `_openAssetDetailDialog` showing read-only `AppInfoTileGrid` (name, tag, status, facility/location, display id) — no new API; reuse `_display`, `_statusLabel`, `_OperationStatusBadge`

### Mobile parity

- **Queue:** update `_OperationsRequestListTile` to include tappable next-action control matching desktop `_OperationsNextActionButton`
- **Assets:** ensure `mobileItemBuilder` shows status + location; row tap opens asset detail dialog

## Implementation Steps

### 1. Add shared l10n keys (`frontend/lib/l10n/app_en.arb`)

Add only to `app_en.arb` (per locale rule):

```json
"commonAdvancedFiltersTitle": "Advanced filters",
"commonTableSettingsTitle": "Table Settings"
```

Run codegen if the project requires it after arb edits.

### 2. Refactor `_operationColumns` and `_operationColumnChoices`

File: `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart`

- Rewrite `_operationColumns` to the 5-column workflow plan above; add explicit `id` on every column
- Rewrite `_operationColumnChoices` to **only** optional columns (`location`, `assignee`, `due`) — remove spread of `_operationColumns` and remove duplicate `next_action` text column
- Add `_operationsWorkItemMatchesSearch` function (mirror Mortuary `_matchesSearch` style)

### 3. Add `_OperationsNextActionButton`

In the same file (or extract to `frontend/lib/features/operations/presentation/widgets/operations_workspace_widgets.dart` if the page grows too large):

- Parameters: `OperationsWorkItem item`, `bool canMutate`, callbacks/refs to open dialogs
- Pass `canMutate` from `_OperationsQueuePanel` (read `appAccessPolicyProvider` + `_mutationRequirement` pattern from parent)

Wire into column 5 `cellBuilder` and mobile list tile.

### 4. Update `_OperationsQueuePanel` `AppListTable`

- `columnVisibilityTitle: l10n.commonTableSettingsTitle`
- `displayMode: AppListTableDisplayMode.adaptive` (explicit)
- `search.advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
- `search.matcher: (item, query) => _operationsWorkItemMatchesSearch(l10n, item, query)`
- Pass `canMutate` into panel for next-action button

### 5. Update `_OperationsAssetsPanel` `AppListTable`

- `columnVisibilityTitle: l10n.commonTableSettingsTitle`
- `displayMode: AppListTableDisplayMode.adaptive`
- `search.advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
- Add `onRowSelected` → `_openAssetDetailDialog`
- Implement `_openAssetDetailDialog` + minimal `_OperationsAssetDetailPanel` using existing formatters

### 6. Update tests

File: `frontend/test/features/operations/presentation/operations_workspace_page_test.dart`

- Assert **Table Settings** and **Advanced filters** titles appear when opening modals (if feasible)
- Assert default queue columns include next-action control for open request
- Assert assets row tap opens detail dialog
- Keep existing tab/count/deep-link tests passing

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` / `AppListTableColumn` / `AppListTableSearch` | `package:hosspi_hms/shared/components/components.dart` | Both tables |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListItemText` | same | Two-line cells |
| `AppWorkspaceStatusBadge` | same | Status badges (`_OperationStatusBadge`) |
| `AppButton` | same | Next-action column (not `WorkflowActionButton`) |
| `AppInfoTileGrid` / `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/layout/layout.dart` | Asset detail dialog |
| `appListTableCompareText` / `appListTableCompareDateTime` | `app_list_table.dart` | Sort comparators |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/operations/presentation/pages/operations_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/operations/presentation/operations_workspace_page_test.dart` |
| Optional create | `frontend/lib/features/operations/presentation/widgets/operations_workspace_widgets.dart` (if extracting next-action / search helpers) |

No files to delete.

## l10n

- Add `commonAdvancedFiltersTitle`, `commonTableSettingsTitle` to `frontend/lib/l10n/app_en.arb` only
- Reuse existing: `commonTableSettingsActionLabel`, `operationsFiltersLabel`, `operationsNextAction*` keys
- Do not rename existing operations-specific column labels

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/operations/
```

## Testing Requirements

- [ ] Queue table: search chrome shows only Filters + Settings
- [ ] Assets table: search chrome shows only Filters + Settings
- [ ] Advanced filters modal title is **Advanced filters**
- [ ] Table Settings modal title is **Table Settings**
- [ ] Column visibility persists per `operations_*` storage key
- [ ] Queue: exactly 5 default columns; row number is automatic
- [ ] Queue: status column 4th, next-action column 5th with explicit verb labels
- [ ] Next-action press opens assign / status / service-log / closeout dialog (not generic navigation)
- [ ] Row tap opens request detail dialog (queue) and asset detail dialog (assets)
- [ ] Mobile list shows priority fields, status, and tappable next action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] `operationsWrite` permission still gates write actions on next-action buttons

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved (tabs, filters, pagination, deep links, mutations, permissions)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/operations/` passes
