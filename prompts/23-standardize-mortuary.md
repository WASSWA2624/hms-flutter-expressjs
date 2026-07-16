# Standardize Mortuary Screen

## Objective

Refactor the Mortuary workspace to match the standardized tab-and-table layout used by the Reception workspace. The Mortuary screen currently uses a single flat `AppWorkspace` + `AppListTable` with panel/resource/queue selection buried in advanced filters (`AppSearchBarFilterGroup`). This refactor replaces that with routable `AppTabStrip` tabs (one per domain panel), URL query deep-linking, tab-specific table columns, and a contextual primary action button next to the tab strip — while preserving summary chips, spotlight queues, detail dialog, print, and all existing read-only controller behavior.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

The workspace root is `d:\coding\apps\flutter\hms`. The frontend code is in `frontend/`. Use `flutter test` and `dart format` from the `frontend/` directory.

## Current State (from audit)

### Files

| File | Purpose |
|------|---------|
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | Main page (~1634 lines). Contains `MortuaryWorkspacePage`, `_MortuaryWorkspaceContent`, `_MortuaryWorklist`, `_MortuaryDetailPanel`, section widgets, `_ActionGapPanel`, print helpers — all in one file. |
| `frontend/lib/features/mortuary/presentation/controllers/mortuary_workspace_controller.dart` | `MortuaryWorkspaceController` — Riverpod `AsyncNotifier` for load/search/filters/queues/paging/detail/realtime. Mutations are not implemented (read-only). |
| `frontend/lib/features/mortuary/domain/entities/mortuary_entities.dart` | Panels, resources, queues, statuses, `MortuaryWorkspaceQuery`, `MortuaryWorkspaceState`, `MortuaryWorkspaceItem`, lookups. |
| `frontend/lib/features/mortuary/domain/repositories/mortuary_repository.dart` | Repository interface: `getWorkspace`, `getLookups`, `getItem`. |
| `frontend/lib/features/mortuary/data/repositories/mortuary_repository_impl.dart` | REST implementation + `mortuaryRepositoryProvider`. |
| `frontend/lib/features/mortuary/data/dtos/mortuary_dtos.dart` | DTOs for workspace payload / items / lookups. |
| `frontend/lib/app/router/app_router.dart` | GoRoute at `/mortuary` — no query extraction. |
| `frontend/lib/app/router/app_routes.dart` | `AppRoutes.mortuary`. |
| `frontend/test/features/mortuary/presentation/mortuary_workspace_controller_test.dart` | Controller tests. |
| `frontend/test/features/mortuary/data/mortuary_dtos_test.dart` | DTO tests. |

### Current layout/structure

- `MortuaryWorkspacePage` → `AppAccessGate` → `AsyncStateScaffold` → `AppWorkspace` with `appWorkspaceToolbarWithLabels`.
- Toolbar: summary notification chips + spotlight queue chips + disabled primary "Receive case" + refresh.
- Body: single `_MortuaryWorklist` with one `AppListTable<MortuaryWorkspaceItem>` for all panels.
- Panel/resource/queue/status/facility/storage filters live in advanced search — **no `AppTabStrip`**.
- Fixed columns for all panels: reference, deceased, source, storage, status (+ billing badge), date, nextAction.
- Row selection opens `_MortuaryDetailPanel` in a modal dialog.
- Primary action `mortuaryReceiveCaseAction` is always `enabled: false`.
- Detail `_ActionGapPanel` shows 8 disabled workflow actions (Receive case, Assign storage, Record custody, Schedule viewing, Post-mortem, Request billing, Approve release, Confirm release).

### Domain panels (already defined)

Constants in `mortuary_entities.dart`:

| Panel constant | Value | Default resource |
|----------------|-------|------------------|
| `mortuaryPanelOverview` | `overview` | `mortuary-cases` |
| `mortuaryPanelIntake` | `intake` | `mortuary-cases` |
| `mortuaryPanelStorage` | `storage` | `mortuary-storage-assignments` |
| `mortuaryPanelCustody` | `custody` | `mortuary-custody-events` |
| `mortuaryPanelRelease` | `release` | `mortuary-release-authorisations` |
| `mortuaryPanelReporting` | `reporting` | `mortuary-post-mortem-requests` |

Queues (spotlight shortcuts, not tabs): `IDENTIFICATION_PENDING`, `STORAGE_EXCEPTIONS`, `RELEASE_READY`, `UNSETTLED_BILLING`, `POST_MORTEM_PENDING`.

Controller already has `switchPanel`, `applyQueue`, `applyFilters`, `applySearch`, `changePage`, `selectItem`, `refresh`.

### Problems/inconsistencies

1. **No routable tabs.** Panels are hidden inside advanced filters.
2. **Same columns for all panels.** Storage/custody/release/reporting items have different meaningful fields.
3. **No URL deep-linking.** Switching panels does not update the URL.
4. **Static primary action.** Always "Receive case" (and disabled), regardless of panel.
5. **No per-tab column visibility storage keys.**

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

| File | What to extract |
|------|-----------------|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | `AppTabStrip`, URL update via `GoRouter.of(context).replace`, per-section columns, primary action next to tabs. |
| `frontend/lib/features/reception/domain/entities/reception_entities.dart` | `ReceptionDeskSection` / route query patterns. |
| `frontend/lib/shared/components/app_tab_strip.dart` | `AppTabStrip` / `AppTabItem` API. |
| `frontend/lib/shared/components/app_list_table.dart` | `AppListTable`, search, column visibility/width storage keys. |
| `frontend/lib/shared/layout/app_workspace.dart` | `AppWorkspace` + toolbar helpers. |
| `frontend/lib/features/biomedical/presentation/pages/biomedical_workspace_page.dart` | Closest peer: panels + `AppTabStrip` + `panel` query param while keeping `AppWorkspace` toolbar. Prefer this pattern over fully replacing `AppWorkspace` with `ResponsivePage` unless Reception-only is required — **keep `AppWorkspace` toolbar/summary/spotlight, put tabs in the body**. |

## Target Architecture

### Tab Configuration

| Tab Name | Panel Constant | Route Query Value | Default Resource | Primary Action Button |
|----------|----------------|-------------------|------------------|----------------------|
| Overview | `mortuaryPanelOverview` | `overview` | cases | "Receive case" (keep disabled until write API exists; wire `onPressed: null` but show button when user has write permission) |
| Intake | `mortuaryPanelIntake` | `intake` | cases | "Receive case" (same) |
| Storage | `mortuaryPanelStorage` | `storage` | storage-assignments | "Assign storage" (disabled stub; preserve existing label from l10n / `_ActionGapPanel`) |
| Custody | `mortuaryPanelCustody` | `custody` | custody-events | "Record custody" (disabled stub) |
| Release | `mortuaryPanelRelease` | `release` | release-authorisations | "Approve release" (disabled stub) |
| Reporting | `mortuaryPanelReporting` | `reporting` | post-mortem-requests | "Post-mortem" (disabled stub) |

### Route query model

Add `MortuaryRouteQuery` to `mortuary_entities.dart`:

```dart
@immutable
final class MortuaryRouteQuery {
  const MortuaryRouteQuery({
    this.panel = '',
    this.search = '',
    this.queue = '',
    this.id = '',
  });

  final String panel;
  final String search;
  final String queue;
  final String id;

  factory MortuaryRouteQuery.fromUri(Uri uri) {
    final Map<String, String> q = uri.queryParameters;
    return MortuaryRouteQuery(
      panel: (q['panel'] ?? q['section'] ?? '').trim(),
      search: (q['search'] ?? '').trim(),
      queue: (q['queue'] ?? '').trim(),
      id: (q['id'] ?? '').trim(),
    );
  }

  String get normalizedPanel {
    final String value = panel.trim().toLowerCase();
    if (mortuaryPanels.contains(value)) {
      return value;
    }
    return mortuaryPanelOverview;
  }

  bool get hasRouteTargeting =>
      panel.isNotEmpty || search.isNotEmpty || queue.isNotEmpty || id.isNotEmpty;
}
```

### Routing

**File:** `frontend/lib/app/router/app_router.dart`

Replace:

```dart
GoRoute(
  path: AppRoutes.mortuary.path,
  name: AppRoutes.mortuary.name,
  builder: (_, _) => const MortuaryWorkspacePage(),
),
```

With:

```dart
GoRoute(
  path: AppRoutes.mortuary.path,
  name: AppRoutes.mortuary.name,
  builder: (_, GoRouterState state) => MortuaryWorkspacePage(
    initialQuery: MortuaryRouteQuery.fromUri(state.uri),
  ),
),
```

### Page layout target

Keep `AppWorkspace` for title/toolbar/summary/spotlight/refresh. Change body to:

```
Column
├─ Row
│  ├─ Expanded → AppTabStrip (6 panels from mortuaryPanels)
│  └─ AppButton.primary (contextual, may be disabled stub)
├─ SizedBox(height: spacing.md)
└─ AppListTable<MortuaryWorkspaceItem>
   ├─ columns: _columnsForPanel(panel)
   ├─ columnVisibilityStorageKey: 'mortuary_$panel'
   ├─ columnWidthStorageKey: 'mortuary_cw_$panel'
   ├─ search: advanced filters WITHOUT panel filter
   ├─ onRowSelected → detail dialog (unchanged)
   └─ mobileItemBuilder (existing / adapted)
```

On tab tap:
1. `setState` current panel
2. `_updateUrlForPanel(panel)`
3. `unawaited(controller.switchPanel(panel))`

### Per-tab columns

Use fields already on `MortuaryWorkspaceItem`. Hide empty-looking columns gracefully with existing dash helpers.

**Overview / Intake** (`mortuary-cases`):
| Column | Fields |
|--------|--------|
| Reference | `effectiveDisplayId` (copyable) |
| Deceased | `deceasedProfileLabel` / `patientLabel` / `title` |
| Source | `sourceDepartment` / `receivedFrom` / `sourceWorkflow` |
| Storage | storage unit + slot labels |
| Status | status + identification/billing badges as today |
| Date | received / relevant date |
| Next Action | existing next-action label |

**Storage** (`mortuary-storage-assignments`):
| Column | Fields |
|--------|--------|
| Reference | `effectiveDisplayId` |
| Deceased / Case | title / deceased label |
| Unit | `storageUnitLabel` / `unitType` |
| Slot | `storageSlotLabel` / `slotCode` |
| Zone | `temperatureZone` |
| Slot Status | `storageSlotStatus` |
| Status | `status` |
| Next Action | existing |

**Custody** (`mortuary-custody-events`):
| Column | Fields |
|--------|--------|
| Reference | `effectiveDisplayId` |
| Event | `eventType` / `title` |
| Actor | `actorName` / `actorRole` |
| Location | `locationLabel` |
| Reason | `reason` |
| Status | `status` |
| Date | event/date field used today |
| Next Action | existing |

**Release** (`mortuary-release-authorisations` / billable):
| Column | Fields |
|--------|--------|
| Reference | `effectiveDisplayId` |
| Deceased | deceased/title |
| Recipient | `recipientName` / `recipientRelationship` |
| Funeral Service | `funeralServiceName` |
| Release Status | `releaseStatus` / `status` |
| Billing | `billingStatus` / `amountText` |
| Approved By | `approvedByName` |
| Next Action | existing |

**Reporting** (`mortuary-post-mortem-requests`):
| Column | Fields |
|--------|--------|
| Reference | `effectiveDisplayId` |
| Deceased | deceased/title |
| Requested By | `requestedByName` |
| Reason | `requestReason` |
| Diagnostics Ref | `diagnosticsReferenceId` |
| Status | `status` |
| Date | relevant date |
| Next Action | existing |

### URL sync

```dart
void _updateUrlForPanel(String panel, {String? queue, String? search}) {
  if (!mounted) return;
  final String location = AppRoutes.mortuary.location(
    queryParameters: <String, String>{
      if (panel != mortuaryPanelOverview) 'panel': panel,
      if ((queue ?? '').isNotEmpty) 'queue': queue!,
      if ((search ?? '').isNotEmpty) 'search': search!,
    },
  );
  GoRouter.of(context).replace<void>(location);
}
```

Deep-link on `initialQuery`:
- Apply `normalizedPanel` via `controller.switchPanel`
- If `queue` set, prefer `controller.applyQueue(queue)` (it already maps panel/resource)
- If `search` set, apply search + set search controller text
- If `id` set, select that item after load when feasible (best-effort; do not break if item not on current page)

### Filters

- **Remove** panel filter group from advanced filters (tabs own panel selection).
- **Keep** resource (optional — only if still useful within a panel; otherwise remove and rely on default resource per panel), queue, status, identification_status, facility, storage unit/slot, date preset.
- Prefer keeping queue filter + spotlight chips; spotlight already calls `applyQueue`.

### Primary action

- Move primary button from toolbar `primary:` to the row beside `AppTabStrip`.
- Set toolbar `primary: null` (keep summaries, spotlight, refresh).
- Use permission gates already used on the page (`AppAccessActionGate` / write permissions).
- Buttons may remain disabled stubs (no write API) — do **not** invent fake mutations. Preserve existing disabled labels from l10n / `_ActionGapPanel`.

### Icons / labels

Add helpers:

```dart
IconData _panelIcon(String panel) { ... }
String _panelLabel(AppLocalizations l10n, String panel) { ... }
```

Suggested icons:
- overview → `Icons.dashboard_outlined`
- intake → `Icons.login_outlined`
- storage → `Icons.kitchen_outlined` or `Icons.inventory_2_outlined`
- custody → `Icons.badge_outlined`
- release → `Icons.outbox_outlined`
- reporting → `Icons.science_outlined`

Reuse existing l10n keys for panel labels if present; otherwise add keys to `app_en.arb` and regenerate localizations (follow project l10n workflow).

## Implementation Steps

### 1. Add `MortuaryRouteQuery` — File: `frontend/lib/features/mortuary/domain/entities/mortuary_entities.dart`

- Add the class shown above.
- Export/use existing `mortuaryPanels` for validation.

### 2. Update router — File: `frontend/lib/app/router/app_router.dart`

- Pass `MortuaryRouteQuery.fromUri(state.uri)` into `MortuaryWorkspacePage`.

### 3. Accept `initialQuery` on page — File: `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart`

- Add optional `initialQuery` to `MortuaryWorkspacePage` and pass to content state.
- Apply deep-link once (signature guard) in `initState` / `didUpdateWidget`.

### 4. Replace panel filter with `AppTabStrip`

- Track `_currentPanel` in content state (default `mortuaryPanelOverview`).
- Build tabs from `mortuaryPanels`.
- On tap: update panel, URL, `controller.switchPanel(panel)`.
- Inline `_MortuaryWorklist` table into content `Column` under the tab row (or keep helper but drive columns/storage keys from `_currentPanel`).

### 5. Per-tab columns + storage keys

- Implement `_columnsForPanel(AppLocalizations l10n, String panel)`.
- Set `columnVisibilityStorageKey: 'mortuary_$_currentPanel'` and `columnWidthStorageKey: 'mortuary_cw_$_currentPanel'`.
- Re-sync column visibility controller when panel changes.

### 6. Contextual primary action

- Implement `_primaryActionForPanel(...)` returning the stub button for the active panel.
- Remove toolbar primary.

### 7. Remove panel filter from advanced filters

- Delete panel filter key/group/choices handling.
- Ensure `onFilterChanged` always sends current tab panel.

### 8. Preserve detail / print / disabled action gap

- Keep `_MortuaryDetailPanel`, sections, print, `_ActionGapPanel` unchanged functionally.
- Keep summary + spotlight behavior; when spotlight applies a queue, sync tab selection + URL to the resulting panel.

### 9. Tests

Update/add:

- Controller: `switchPanel` updates query panel + default resource; resets page; clears selection as today.
- Route query: `MortuaryRouteQuery.fromUri` parses `panel`/`section`/`search`/`queue`/`id`.
- Page/widget test (lightweight): tab strip present; tapping a tab invokes panel switch (mock controller / Provider overrides following other workspace page tests if patterns exist).
- Fix any stale controller expectations (do not auto-select item on load unless current code does).

### 10. Verify

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/mortuary/
flutter test test/shared/
```

## Shared Components — MUST Reuse

| Component | Usage |
|-----------|-------|
| `AppTabStrip` / `AppTabItem` | 6 mortuary panels |
| `AppListTable` / `AppListTableSearch` | Per-tab columns + filters without panel |
| `AppListTableColumnVisibilityController` | Re-sync per tab |
| `AppWorkspace` / `appWorkspaceToolbarWithLabels` | Keep summaries/spotlight/refresh |
| `AppButton.primary` | Contextual primary next to tabs |
| `AsyncStateScaffold` | Keep |
| `GoRouter` + `AppRoutes.mortuary` | URL sync |

Do NOT re-implement tab bars, tables, or workspace shells.

## Files to Create

| File Path | Purpose |
|-----------|---------|
| (none required) | Prefer modifying existing files. Add a page test file only if needed: `frontend/test/features/mortuary/presentation/mortuary_workspace_page_test.dart`. |

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/mortuary/domain/entities/mortuary_entities.dart` | Add `MortuaryRouteQuery`. |
| `frontend/lib/features/mortuary/presentation/pages/mortuary_workspace_page.dart` | Tabs, columns, URL sync, primary action move, remove panel filter. |
| `frontend/lib/app/router/app_router.dart` | Extract URI query into page. |
| `frontend/lib/l10n/app_en.arb` (+ generated l10n if required) | Panel labels if missing. |
| `frontend/test/features/mortuary/presentation/mortuary_workspace_controller_test.dart` | Cover `switchPanel` / queue→panel; fix stale expectations. |
| Optional page test | Tab + deep-link smoke coverage. |

## Files to Delete

| File Path | Reason |
|-----------|--------|
| (none) | Remove only private helpers inside the page file (panel filter), not standalone files. |

## Cleanup: Remove Stale Code

- [ ] Remove panel filter key/group/choices from advanced filters
- [ ] Remove unused panel-filter helpers
- [ ] Remove toolbar primary once moved beside tabs
- [ ] Remove unused imports
- [ ] Ensure analyze is clean (no dead symbols)

## Database Migrations

None. Frontend UI/navigation only. Backend query params (`panel`, `resource`, `queue`, etc.) already supported by controller/API.

## Responsive Design Requirements

- Desktop: full table + horizontal tab strip + primary action on the right of tabs.
- Tablet: compact columns; tabs may scroll horizontally.
- Mobile: `mobileItemBuilder` list layout; scrolling tabs; primary action may wrap under tabs.

Rely on shared `AppListTable` / `AppTabStrip` breakpoint behavior.

## Verification Steps

```bash
cd frontend
dart format .
dart analyze --fatal-infos
flutter test test/features/mortuary/
flutter test test/shared/
```

## Testing Requirements

- [ ] Switching tabs calls `controller.switchPanel` with the correct panel
- [ ] URL updates with `panel` query param (omit for overview default)
- [ ] Deep link `?panel=storage` opens Storage tab
- [ ] Queue spotlight still switches to mapped panel and syncs tab/URL
- [ ] Each tab uses `_columnsForPanel` + unique storage keys
- [ ] Panel filter removed from advanced filters
- [ ] Primary action label changes per tab (even if disabled)
- [ ] Detail dialog + print still work
- [ ] Existing DTO/controller tests pass

## Acceptance Criteria

- [ ] `AppTabStrip` with 6 tabs matching `mortuaryPanels`
- [ ] Deep-linkable `panel` (and optional `queue`/`search`/`id`) query params
- [ ] Contextual primary action next to tabs (stubs OK if write APIs absent)
- [ ] Per-tab column sets + visibility/width storage keys
- [ ] Panel filter removed from advanced filters
- [ ] `AppWorkspace` summary/spotlight/refresh preserved
- [ ] No shared component re-implemented
- [ ] Domain read behavior preserved; no fake write mutations invented
- [ ] No DB migrations
- [ ] `dart analyze` clean; mortuary tests pass
