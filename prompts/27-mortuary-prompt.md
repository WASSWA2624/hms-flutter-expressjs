# Standardize Mortuary Tables

## Objective

Refactor every `AppListTable` on the Mortuary workspace (`/mortuary`, `MortuaryWorkspacePage`) so each table fully complies with `prompt.md` (search chrome, ≤5 columns, status/action columns when applicable, row detail dialog, responsiveness, realtime).

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

**Scope boundary:** Restructure **table chrome, columns, and row interactions only**. Do not rewrite domain APIs, permissions, or unrelated screen chrome unless required for compilation. Preserve existing tab toolbar actions (primary/secondary including Refresh), deep links (`?panel=`, `?queue=`, `?search=`, `?id=`), pagination, filter groups, and the existing `_openMortuaryDetailDialog` / `_MortuaryDetailPanel` content.

## Current State (from audit)

### Screen layout

| Field | Value |
|-------|-------|
| Route | `/mortuary` |
| Page widget | `MortuaryWorkspacePage` |
| Primary file | `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` |
| Controller | `mortuaryWorkspaceControllerProvider` → `MortuaryWorkspaceController` |
| Entity (row) | `MortuaryWorkspaceItem` |
| Deep link | `?panel=<value>` (also `queue`, `search`, `id`) |

**Tabs (actual code — not the stale generator shorthand):** six panels from `mortuaryPanels` in `mortuary_entities.dart`:

| Panel id | l10n label | Default resource (`mortuaryDefaultResourceByPanel`) |
|----------|------------|-----------------------------------------------------|
| `overview` | `mortuaryPanelOverviewLabel` → "Overview" | `mortuary-cases` |
| `intake` | `mortuaryPanelIntakeLabel` → "Intake" | `mortuary-cases` |
| `storage` | `mortuaryPanelStorageLabel` → "Storage" | `mortuary-storage-assignments` |
| `custody` | `mortuaryPanelCustodyLabel` → "Custody" | `mortuary-custody-events` |
| `release` | `mortuaryPanelReleaseLabel` → "Release" | `mortuary-release-authorisations` |
| `reporting` | `mortuaryPanelReportingLabel` → "Reports" | `mortuary-post-mortem-requests` |

One shared table widget `_MortuaryWorklist` renders for every panel; panel switch resets `AppListTableColumnVisibilityController` in `_MortuaryWorkspaceContentState._switchPanel` but **does not** vary columns per panel today.

### Table inventory

| # | Widget | File | Entity | Tabs | Detail on row select |
|---|--------|------|--------|------|----------------------|
| 1 | `_MortuaryWorklist` | `mortuary_workspace_page.dart` | `MortuaryWorkspaceItem` | All 6 panels | `onRowSelected` → `onItemSelected` → `_openMortuaryDetailDialog` (loads detail via `controller.selectItem`, shows `AppDialog` + `_MortuaryDetailPanel`) |

### Current columns (`_MortuaryWorklist._columns`) — **7 declared (violates ≤5)**

| # | Column id | Label key | Source field(s) | Cell pattern | Sort |
|---|-----------|-----------|-----------------|--------------|------|
| 1 | `reference` | `mortuaryReferenceColumnLabel` | `effectiveDisplayId` + `resource` subtitle | `_ReferenceCell` (copyable ID + resource label) | `effectiveDisplayId` |
| 2 | `deceased` | `mortuaryDeceasedColumnLabel` | `effectiveDeceasedLabel` + `patientLabel`/`deceasedProfileId` | `_TwoLineCell` | `effectiveDeceasedLabel` |
| 3 | `source` | `mortuarySourceColumnLabel` | `sourceLabel` + `receivedFrom` | `_SourceCell` | none |
| 4 | `storage` | `mortuaryStorageColumnLabel` | `storageLabel` + slot status | `_TwoLineCell` | none |
| 5 | `status` | `mortuaryStatusColumnLabel` | `caseStatus`/`status` **and** `caseBillingStatus`/`billingStatus` | Two `AppWorkspaceStatusBadge` in one column | none |
| 6 | `date` | `mortuaryDateColumnLabel` | `timelineAt` | `Text` formatted | `timelineAt` |
| 7 | `nextAction` | `mortuaryNextActionColumnLabel` | derived via `_nextActionLabel` | Plain `Text` (not actionable) | none |

### Current search chrome

- `AppListTableSearch` with `showAdvancedFilterButton: true`, `advancedFilterButtonLabel: l10n.mortuaryFiltersLabel` ("Filters"), `advancedFilterTitle: l10n.mortuaryFiltersLabel` (**should be "Advanced filters"** per `prompt.md`).
- Settings via `columnVisibilityLabel: l10n.commonTableSettingsActionLabel` ("Settings"); `columnVisibilityTitle` incorrectly set to same "Settings" label (**should be "Table Settings"**).
- `columnVisibilityApplyLabel` / `columnVisibilityResetLabel` use mortuary-specific filter strings (`mortuaryApplyFiltersAction`, `mortuaryResetFiltersAction`) — acceptable if no shared keys exist.
- **Missing:** `columnVisibilityStorageKey`, `columnWidthStorageKey`.
- **Missing:** `displayMode: AppListTableDisplayMode.adaptive`.
- `columnChoices: columns` — all 7 columns exposed; no split between default visible vs optional hidden columns.
- Refresh lives in tab toolbar (`commonRefreshActionLabel`) — correct per `prompt.md` (not in search chrome).
- Existing test `table chrome exposes Filters and Settings only` in `mortuary_workspace_page_test.dart` must keep passing.

### Search matcher gaps (`_matchesSearch`)

Currently matches: `effectiveDisplayId`, `effectiveDeceasedLabel`, `patientLabel`, `sourceLabel`, `storageLabel`, `caseStatus`, `caseBillingStatus`, `facilityLabel`.

**Missing** fields used by columns or that should be searchable when moved to `columnChoices`: `deceasedProfileId`, `receivedFrom`, `sourceReferenceId`, `sourceDepartment`, `sourceWorkflow`, `storageSlotStatus`, `storageAssignment?.status`, `identificationStatus`, `billingStatus` (non-case rows), `timelineAt` (formatted), `_nextActionLabel` text, `_resourceLabel` text, `eventType`, `actorName`, `recipientName`, `status` (raw).

### Mobile builder gaps (`_MortuaryMobileListItem`)

- Shows deceased + concatenated subtitle (ID | storage | status) — partial parity.
- **Missing:** explicit next-action control, proper `AppWorkspaceStatusBadge`, priority field alignment with desktop defaults per panel.

### Workflow / next-action logic (preserve)

`_nextActionLabel(l10n, item)` priority (do not change business rules):

1. Identification not `VERIFIED` → `mortuaryNextActionVerifyIdentity`
2. No `storageLabel` and status ≠ `RELEASED` → `mortuaryNextActionAssignStorage`
3. Status `POST_MORTEM_PENDING` → `mortuaryNextActionPostMortem`
4. Billing not settled (`SETTLED`/`PAID`/`CANCELLED`) → `mortuaryNextActionClearBilling`
5. Status `READY_FOR_RELEASE` → `mortuaryNextActionApproveRelease`
6. Status `RELEASED`/`CLOSED` → `mortuaryNextActionReleased`
7. Default → `mortuaryNextActionReview`

`WorkflowActionRegistry` has **no** `mortuary` module entry today — do **not** wire `WorkflowActionButton` until registry support exists. Use a module-local actionable control (see Target Architecture).

### Realtime (already wired — preserve)

- `MortuaryWorkspaceController` listens to `RealtimeEventGroups.mortuary` and adaptive polling.
- Table reads `state.items` from `mortuaryWorkspaceControllerProvider` — no direct mutation.

### Gap summary vs `prompt.md`

| Gap | Severity |
|-----|----------|
| 7 declared columns (max 5) | Blocker |
| Status column merges case + billing status | Blocker |
| Next-action is plain text, not actionable | Blocker |
| No `columnVisibilityStorageKey` / `columnWidthStorageKey` | Blocker |
| `columnVisibilityTitle` wrong | Required |
| `advancedFilterTitle` not "Advanced filters" | Required |
| `columnChoices` not split from defaults | Required |
| Same columns for all panels (suboptimal triage) | Required |
| Search matcher incomplete | Required |
| No `displayMode: adaptive` | Required |
| Mobile missing status badge + next-action | Required |
| `_TwoLineCell` instead of shared `AppListItemText` | Minor (prefer `AppListItemText`) |

## Reference Implementation

- `frontend/lib/shared/components/app_list_table.dart` — `AppListTable`, `AppListTableColumn`, `AppListTableSearch`, `AppListTableColumnVisibilityController`
- `frontend/lib/shared/components/app_list_item_text.dart` — `AppListItemText`
- `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` — `_MortuaryWorklist` (Filters/Settings chrome reference; reduce columns)
- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart` — per-section `columns` + `columnChoices` split pattern
- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart` — ≤5 columns, status badge, `WorkflowActionButton` next-action pattern (adapt for mortuary without registry)
- `frontend/lib/features/emergency/presentation/widgets/emergency_workspace_widgets.dart` — `emergencyNextActionColumn`, `AppWorkspaceStatusBadge` usage
- `frontend/lib/features/housekeeping/presentation/pages/housekeeping_workspace_page.dart` — storage keys, filter wiring
- `prompt.md`

## Target Architecture

### Table inventory

| Table widget | Tab / panel | Entity | Default visible columns (max 5) | columnVisibilityStorageKey |
|--------------|-------------|--------|-----------------------------------|----------------------------|
| `_MortuaryWorklist` | `overview`, `intake` | `MortuaryWorkspaceItem` (cases) | deceased, reference, source, status, next_action | `mortuary_overview` / `mortuary_intake` (use panel id) |
| `_MortuaryWorklist` | `storage` | assignments | deceased, storage, status, date, next_action | `mortuary_storage` |
| `_MortuaryWorklist` | `custody` | custody events | deceased, event, actor, date, status | `mortuary_custody` |
| `_MortuaryWorklist` | `release` | release authorisations | deceased, recipient, status, date, next_action | `mortuary_release` |
| `_MortuaryWorklist` | `reporting` | post-mortem requests | deceased, request, scheduled, status, next_action | `mortuary_reporting` |

Also set `columnWidthStorageKey: 'mortuary_cw_<panel>'` per panel.

Pass `state.query.panel` into `_MortuaryWorklist` (add parameter) so column builders and storage keys are panel-aware. Recreate column visibility controller on panel switch (already done).

### Column plan — case panels (`overview`, `intake`)

| Position | Column id | Label | Source field | Notes |
|----------|-----------|-------|--------------|-------|
| 1 | `deceased` | `mortuaryDeceasedColumnLabel` | `effectiveDeceasedLabel` + `patientLabel` or `deceasedProfileId` | `AppListItemText`; one semantic field |
| 2 | `reference` | `mortuaryReferenceColumnLabel` | `effectiveDisplayId` + resource type label | `AppListItemText` or keep `_ReferenceCell` |
| 3 | `source` | `mortuarySourceColumnLabel` | `sourceLabel` + `receivedFrom` | `AppListItemText` |
| 4 | `status` | `mortuaryStatusColumnLabel` | `caseStatus ?? status` only | Single `AppWorkspaceStatusBadge` via `_statusTone`; **remove billing badge from this column** |
| 5 | `next_action` | `mortuaryNextActionColumnLabel` | `_nextActionLabel` | `_MortuaryNextActionButton` (see below); `alwaysVisible: true` |

**`columnChoices` (hidden by default):** `storage`, `date`, `billing_status` (new id — `caseBillingStatus ?? billingStatus` with `_billingTone` badge), `facility` (`facilityLabel`), `identification` (`caseIdentificationStatus`).

### Column plan — `storage` panel

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `deceased` | `mortuaryDeceasedColumnLabel` | case/deceased context from item | |
| 2 | `storage` | `mortuaryStorageColumnLabel` | `storageLabel` + slot status subtitle | |
| 3 | `status` | `mortuaryStatusColumnLabel` | assignment/slot status | badge |
| 4 | `date` | `mortuaryDateColumnLabel` | `timelineAt` or `storageAssignment?.assignedAt` | |
| 5 | `next_action` | `mortuaryNextActionColumnLabel` | `_nextActionLabel` | button |

**`columnChoices`:** `reference`, `source`, `facility`, `billing_status`.

### Column plan — `custody` panel

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `deceased` | `mortuaryDeceasedColumnLabel` | deceased/case label | |
| 2 | `event` | `mortuaryCustodySectionTitle` or new `mortuaryEventColumnLabel` | `eventType` | formatted via `_displayCode` |
| 3 | `actor` | `mortuaryActorFieldLabel` | `actorName` + `actorRole` subtitle | `AppListItemText` |
| 4 | `date` | `mortuaryDateColumnLabel` | `eventAt ?? timelineAt` | |
| 5 | `status` | `mortuaryStatusColumnLabel` | custody-related status if present | badge; no generic next-action for event rows — use `mortuaryNextActionReview` only when `item.isCase` |

**`columnChoices`:** `location` (`locationLabel`), `reference`, `notes` (`notes`/`reason`).

### Column plan — `release` panel

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `deceased` | `mortuaryDeceasedColumnLabel` | deceased label | |
| 2 | `recipient` | `mortuaryReleaseFieldLabel` | `recipientName` + `recipientRelationship` | |
| 3 | `status` | `mortuaryStatusColumnLabel` | `status` / `releaseStatus` | badge |
| 4 | `date` | `mortuaryDateColumnLabel` | `releasedAt ?? approvedAt ?? timelineAt` | |
| 5 | `next_action` | `mortuaryNextActionColumnLabel` | `_nextActionLabel` | button |

**`columnChoices`:** `reference`, `verification` (`verificationReference`), `funeral_service` (`funeralServiceName`).

### Column plan — `reporting` panel

| Position | Column id | Label | Source | Notes |
|----------|-----------|-------|--------|-------|
| 1 | `deceased` | `mortuaryDeceasedColumnLabel` | deceased label | |
| 2 | `request` | `mortuaryPostMortemSectionTitle` or new key | `requestReason` / `diagnosticsReferenceId` | |
| 3 | `scheduled` | `mortuaryDateColumnLabel` | `scheduledAt` | |
| 4 | `status` | `mortuaryStatusColumnLabel` | post-mortem `status` | badge |
| 5 | `next_action` | `mortuaryNextActionColumnLabel` | `_nextActionLabel` | button |

**`columnChoices`:** `requested_by` (`requestedByName`), `reference`, `completed` (`completedAt`).

### `_MortuaryNextActionButton` (new private widget in same file)

Because `WorkflowActionButton` has no mortuary registry entry and toolbar/detail actions are currently disabled (`mortuaryActionsUnavailableTooltip`), implement a compact actionable control:

```dart
class _MortuaryNextActionButton extends StatelessWidget {
  const _MortuaryNextActionButton({
    required this.label,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: enabled ? onPressed : null,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}
```

- Wire `onPressed` to the same `onItemSelected(item)` callback used by `onRowSelected` (opens detail dialog).
- Stop propagation is handled by `TextButton` consuming the tap inside the row.
- For terminal states (`mortuaryNextActionReleased`), render disabled button or plain text — keep label explicit.
- When write actions become available later, this widget is the single swap point for `WorkflowActionButton`.

### Search chrome (per table)

- Expand `_matchesSearch` to include **every** field surfaced in `columns` and `columnChoices` for the active panel (use a shared `_mortuarySearchHaystack(MortuaryWorkspaceItem item, AppLocalizations l10n)` helper).
- `advancedFilterButtonLabel`: keep `l10n.mortuaryFiltersLabel` ("Filters") or add/use shared `commonFiltersActionLabel` if you add it to `app_en.arb`.
- `advancedFilterTitle`: **`l10n.commonAdvancedFiltersTitle`** (add key → "Advanced filters") — do not reuse the button label.
- `columnVisibilityLabel`: `l10n.commonTableSettingsActionLabel` ("Settings").
- `columnVisibilityTitle`: **`l10n.commonTableSettingsTitle`** (add key → "Table Settings").
- Preserve existing `filterGroups`, `onFilterChanged`, `hasActiveFilters`, `filterValue` wiring.
- Do **not** add Refresh/Export to search chrome.

### Row interaction

- Keep `onRowSelected: onItemSelected` → `_openMortuaryDetailDialog`.
- Next-action button uses same destination.
- Detail dialog (`_MortuaryDetailPanel`) and `_ActionGapPanel` disabled actions — unchanged.

### Responsiveness

- Add `displayMode: AppListTableDisplayMode.adaptive`.
- Replace `_MortuaryMobileListItem` with panel-aware builder showing: primary identifier (deceased), top 1–2 priority fields for panel, `AppWorkspaceStatusBadge` for status, and `_MortuaryNextActionButton` when workflow applies.
- Follow `AppListItemRow` pattern from `operations_workspace_page.dart` mobile items if helpful.

## Implementation Steps

### 1. Refactor `_MortuaryWorklist` — `mortuary_workspace_page.dart`

1. Add `panel` parameter (`String`, from `state.query.panel`).
2. Add storage keys:
   - `columnVisibilityStorageKey: 'mortuary_$panel'`
   - `columnWidthStorageKey: 'mortuary_cw_$panel'`
3. Fix titles:
   - `columnVisibilityTitle: l10n.commonTableSettingsTitle`
   - `search.advancedFilterTitle: l10n.commonAdvancedFiltersTitle`
4. Add `displayMode: AppListTableDisplayMode.adaptive`.
5. Split column definitions:
   - Create `_defaultColumnsForPanel(BuildContext, String panel)` returning ≤5 columns.
   - Create `_columnChoicesForPanel(BuildContext, String panel)` returning superset including defaults + optional columns (mirror clinical pattern: `columnChoices` includes all toggleable columns; defaults are the visible subset).
6. Refactor status column: **one** `AppWorkspaceStatusBadge` per row for the primary workflow status of that panel.
7. Add `_MortuaryNextActionButton` in next-action column for case/workflow rows (`item.isCase` or panel in `overview|intake|storage|release|reporting`).
8. Replace `_TwoLineCell` usages in table columns with `AppListItemText` where straightforward.
9. Expand `_matchesSearch` / add `_mortuarySearchHaystack`.
10. Update `_MortuaryMobileListItem` → `_mortuaryMobileItemBuilder(context, panel, item, onItemSelected)`.

### 2. Wire panel into worklist — `_MortuaryWorkspaceContent.build`

```dart
_MortuaryWorklist(
  state: state,
  panel: _currentPanel,
  controller: controller,
  searchController: _searchController,
  tableColumnController: _tableColumnController,
  onItemSelected: (MortuaryWorkspaceItem item) {
    unawaited(_openMortuaryDetailDialog(context, item));
  },
),
```

### 3. l10n — `frontend/lib/l10n/app_en.arb`

Add (if absent):

```json
"commonTableSettingsTitle": "Table Settings",
"@commonTableSettingsTitle": { "description": "Modal title for table column visibility settings." },
"commonAdvancedFiltersTitle": "Advanced filters",
"@commonAdvancedFiltersTitle": { "description": "Modal title for table advanced filters." }
```

Optional new column labels only if reusing section titles is awkward:

- `mortuaryEventColumnLabel`: "Event"
- `mortuaryRecipientColumnLabel`: "Recipient"

Run codegen: `cd frontend && flutter gen-l10n` (or project-standard l10n command).

### 4. Tests — `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart`

Update/add tests:

- Assert ≤5 default column headers visible on desktop (count `AppListTable` header cells minus row-number column).
- Assert `columnVisibilityStorageKey` is set (indirectly: switch panel, toggle column in Settings, switch away and back — column preference persists for session). Use `SharedPreferences` mock already in harness.
- Keep existing tests: tab strip, Filters/Settings only, filter dialog excludes Panel group, deep links, mobile viewport.
- Add: tapping next-action `TextButton` opens detail dialog (`mortuaryDetailTitle`).
- Add: mobile viewport shows status badge or next-action for case row.

### 5. Do **not** change

- `MortuaryWorkspaceController` / repository / DTOs
- Tab toolbar primary/secondary actions
- Permission requirements (`_writeRequirement`, etc.)
- `_ActionGapPanel` disabled actions (business backlog)

## Shared Components — MUST Reuse

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppListTable` | `package:hosspi_hms/shared/components/components.dart` | Table shell |
| `AppListTableColumn` | same | Column defs |
| `AppListTableSearch` | same | Search + Filters |
| `AppListTableColumnVisibilityController` | same | Session column visibility |
| `AppListTableDisplayMode` | same | `adaptive` |
| `AppListItemText` | same | Two-line single-field cells |
| `AppWorkspaceStatusBadge` | same | Status column |
| `AppCopyableIdentifier` | same | Reference cells |
| `WorkflowActionButton` | `package:hosspi_hms/shared/workflow_actions/workflow_action_button.dart` | **Do not use yet** — no mortuary registry |

## Files to Create / Modify / Delete

| Action | Path |
|--------|------|
| Modify | `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` |
| Modify | `frontend/lib/l10n/app_en.arb` |
| Modify | `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart` |
| Modify | Generated l10n outputs (via codegen) |
| Delete | None |

## Database Migrations

No database migrations required — schema unchanged.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/mortuary/
```

## Testing Requirements

- [ ] Each table: search, Filters, Settings only in chrome
- [ ] Column visibility persists for session per `mortuary_<panel>` key
- [ ] ≤5 default columns; row number automatic
- [ ] Workflow tables: explicit status + next-action labels
- [ ] Row tap opens detail dialog
- [ ] Next-action button opens same detail dialog
- [ ] Mobile list shows same priority fields, status, and action
- [ ] Realtime refresh still updates rows after mutations/events
- [ ] Permissions still gate write actions (toolbar + detail remain disabled as today)

## Acceptance Criteria

- [ ] Fully compliant with `prompt.md` for every table on this screen
- [ ] Domain logic preserved (`_nextActionLabel` rules, filters, panels, deep links)
- [ ] `dart analyze --fatal-infos` clean; `flutter test test/features/mortuary/` passes
