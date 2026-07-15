# Standardize Communications Screen

## Objective

Refactor the Communications workspace to align with the standardized tab-and-table layout established by the Reception workspace. The primary changes are: replace `AppWorkspaceOptionToggle` with `AppTabStrip` for panel navigation, add a contextual primary action button alongside the tab bar, adopt per-tab URL synchronization matching the Reception pattern, and ensure the responsive layout follows the same `ResponsivePage` structure. The unique inbox/messaging panel must be preserved as-is while the Notifications, Deliveries, and Templates tabs are brought into full alignment with the Reception reference.

## Context for the Executing Agent

You are a coding AI agent with full read/write access to this Flutter codebase. Execute every step below precisely. Do not skip steps. Do not ask for clarification — all information needed is in this prompt. Run tests and formatting after implementation.

## Current State (from audit)

- **Main page:** `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`
- **Controller:** `frontend/lib/features/communications/presentation/controllers/communications_workspace_controller.dart`
- **Entities:** `frontend/lib/features/communications/domain/entities/communications_entities.dart`
- **Repository interface:** `frontend/lib/features/communications/domain/repositories/communications_repository.dart`
- **Repository impl:** `frontend/lib/features/communications/data/repositories/communications_repository_impl.dart`
- **DTOs:** `frontend/lib/features/communications/data/dtos/communications_dtos.dart`
- **Widgets:**
  - `frontend/lib/features/communications/presentation/widgets/communications_inbox_panel.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_conversation_list.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_thread_view.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_compose_bar.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_mention_utils.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_formatters.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_new_conversation_dialog.dart`
  - `frontend/lib/features/communications/presentation/widgets/communications_manage_members_dialog.dart`
- **Config:** `frontend/lib/features/communications/presentation/config/communications_message_filters.dart`
- **Route:** Defined in `frontend/lib/app/router/app_router.dart` at path `/communications` using `CommunicationsWorkspaceQuery.fromUri(state.uri)`
- **Tests:**
  - `frontend/test/features/communications/presentation/communications_workspace_controller_test.dart`
  - `frontend/test/features/communications/presentation/config/communications_message_filters_test.dart`
  - `frontend/test/features/communications/data/dtos/communications_dtos_test.dart`

### Current Problems/Inconsistencies

1. **Panel switcher uses `AppWorkspaceOptionToggle`** instead of `AppTabStrip` — does not show counts per panel, does not match the tab-strip visual pattern used by Reception.
2. **No primary action button alongside tabs** — the "New Conversation" action is buried inside the inbox panel. Reception places a primary action button (`AppButton.primary`) in a `Row` next to the `AppTabStrip`.
3. **Uses `AppWorkspace` wrapper** — provides toolbar/summary-notifications. Reception uses `ResponsivePage` directly with an inline `AppTabStrip`. The Communications screen should retain its toolbar/summary pattern (it provides real value) but switch to `AppTabStrip` for the panel selector.
4. **URL sync is partial** — panel changes trigger URL updates via `_syncRoute`, but the pattern differs from Reception's simpler `_updateUrlForSection` approach.
5. **Detail panel is conditionally rendered** — The page has a list/detail split (`body` + `detail` on `AppWorkspace`). This is correct for the inbox but inconsistent for table panels where row selection shows detail in a side panel. This should remain for now.

## Reference Implementation

Read these files to understand the target patterns (do NOT modify them):

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
  - **Tab structure:** Uses `AppTabStrip` with `AppTabItem` entries, each having `id`, `icon`, `label` (label includes count: `"${label} (${count})"`)
  - **Primary action button:** `AppButton.primary` placed in a `Row` next to the tab strip
  - **URL sync:** `_updateUrlForSection()` calls `GoRouter.of(context).replace<void>(location)` when tab changes
  - **Table:** `AppListTable<T>` with `columnVisibilityController`, `columnVisibilityStorageKey`, `columnWidthStorageKey`, `search`, `emptyBuilder`, `mobileItemBuilder`
  - **Search:** `AppListTableSearch<T>` with a client-side `matcher` function
- `frontend/lib/shared/components/app_tab_strip.dart`
  - `AppTabStrip` widget: takes `tabs: List<AppTabItem>`, `selectedId: String?`, `onTabTapped: ValueChanged<String>`
  - `AppTabItem`: `id: String`, `icon: IconData`, `label: String`
- `frontend/lib/shared/components/app_list_table.dart`
  - `AppListTable<T>`: main data table with column visibility, search, pagination, mobile builder
  - `AppListTableSearch<T>`: search bar configuration
  - `AppListTableColumnVisibilityController<T>`: manages column show/hide state
- `frontend/lib/shared/layout/app_workspace_option_toggle.dart`
  - `AppWorkspaceOptionToggle<T>`: the widget being replaced by `AppTabStrip`
- `frontend/lib/shared/layout/app_workspace.dart`
  - `AppWorkspace`: high-level workspace layout with title, toolbar, body, detail

## Target Architecture

### Tab Configuration

| Tab Name | Panel Enum Value | Icon | Description | Primary Action Button |
|----------|-----------------|------|-------------|----------------------|
| Inbox | `CommunicationsPanel.inbox` | `Icons.forum_outlined` | Real-time messaging conversations | "New Conversation" → opens `CommunicationsNewConversationDialog` |
| Notifications | `CommunicationsPanel.notifications` | `Icons.notifications_none_outlined` | System notifications list | (none — read-only table) |
| Deliveries | `CommunicationsPanel.deliveries` | `Icons.mark_email_read_outlined` | Notification delivery audit log | (none — read-only table) |
| Templates | `CommunicationsPanel.templates` | `Icons.description_outlined` | Communication templates management | (none — read-only table) |

### Routing

No router file changes needed. The current route definition in `frontend/lib/app/router/app_router.dart` already passes `CommunicationsWorkspaceQuery.fromUri(state.uri)` which includes the `panel` query parameter. URL sync will be updated within the page itself.

### Page Layout

The refactored `_CommunicationsWorkspaceContent` widget tree:

```
AppWorkspace (retain — provides title, toolbar, summary notifications)
  └─ body: Column
       ├─ Row (tab bar + primary action)
       │    ├─ Expanded → AppTabStrip (replaces AppWorkspaceOptionToggle)
       │    └─ SizedBox(width: spacing.sm)
       │    └─ _PrimaryActionButton (contextual per tab, only shows for inbox)
       ├─ SizedBox(height: spacing.md)
       └─ _tableOrInboxForPanel(...)
  └─ detail: _CommunicationsDetailPanel (unchanged — shows for non-inbox panels)
```

### Data & State Management

No changes to the controller (`CommunicationsWorkspaceController`) or repository layer. The existing `communicationsWorkspaceControllerProvider` already provides all panel data. The refactoring is purely UI-layer.

## Implementation Steps

### 1. Replace `_PanelSelector` with `AppTabStrip` — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

- **Delete** the entire `_PanelSelector` widget class (lines ~390–417).
- In `_CommunicationsListPanel.build()`, replace the usage of `_PanelSelector(selected: state.query.panel)` with an `AppTabStrip` widget built from `CommunicationsPanel.values`.
- Move the tab strip OUT of `_CommunicationsListPanel` and INTO the `_CommunicationsWorkspaceContent.build()` method, placing it in a `Row` alongside a primary action button.

### 2. Add tab strip with counts and primary action to `_CommunicationsWorkspaceContent.build()` — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

- Replace the current `body:` content of `AppWorkspace` with a `Column` that starts with:

```dart
Row(
  children: <Widget>[
    Expanded(
      child: AppTabStrip(
        tabs: <AppTabItem>[
          for (final CommunicationsPanel panel in CommunicationsPanel.values)
            AppTabItem(
              id: panel.serverValue,
              icon: _panelIcon(panel),
              label: '${_panelTitle(l10n, panel)} (${_panelCount(state, panel)})',
            ),
        ],
        selectedId: state.query.panel.serverValue,
        onTabTapped: (String tabId) {
          final CommunicationsPanel panel = CommunicationsPanel.fromServer(tabId);
          controller.applyPanel(panel);
        },
      ),
    ),
    if (state.query.panel == CommunicationsPanel.inbox && canWrite) ...<Widget>[
      SizedBox(width: Theme.of(context).spacing.sm),
      AppButton.primary(
        label: l10n.communicationsNewConversationAction,
        leadingIcon: Icons.add_comment_outlined,
        onPressed: () => _openNewConversation(context, ref),
      ),
    ],
  ],
),
SizedBox(height: Theme.of(context).spacing.md),
```

- Add a helper method `_panelCount` that returns the count for each panel:

```dart
int _panelCount(CommunicationsWorkspaceState state, CommunicationsPanel panel) {
  return switch (panel) {
    CommunicationsPanel.inbox => state.conversations.items.length,
    CommunicationsPanel.notifications => state.notifications.totalItemCount ?? state.notifications.items.length,
    CommunicationsPanel.deliveries => state.deliveries.totalItemCount ?? state.deliveries.items.length,
    CommunicationsPanel.templates => state.templates.totalItemCount ?? state.templates.items.length,
  };
}
```

- Add import for `AppTabStrip`:

```dart
import 'package:hosspi_hms/shared/components/app_tab_strip.dart';
```

### 3. Add `columnVisibilityStorageKey` and `columnWidthStorageKey` to all `AppListTable` instances — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

- `_NotificationsTable`: add `columnVisibilityStorageKey: 'communications_notifications'` and `columnWidthStorageKey: 'communications_cw_notifications'`
- `_DeliveriesTable`: add `columnVisibilityStorageKey: 'communications_deliveries'` and `columnWidthStorageKey: 'communications_cw_deliveries'`
- `_TemplatesTable`: add `columnVisibilityStorageKey: 'communications_templates'` and `columnWidthStorageKey: 'communications_cw_templates'`

This matches Reception's pattern: `columnVisibilityStorageKey: 'reception_${_section.name}'`

### 4. Add column `id` fields to all `AppListTableColumn` definitions — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

Every `AppListTableColumn` must have an explicit `id:` parameter for column visibility persistence. Add IDs matching the column semantic:

**Notifications table columns:**
- `id: 'alert'`
- `id: 'type'`
- `id: 'priority'`
- `id: 'state'`
- `id: 'time'`

**Deliveries table columns:**
- `id: 'notification'`
- `id: 'channel'`
- `id: 'recipient'`
- `id: 'status'`
- `id: 'attempts'`

**Templates table columns:**
- `id: 'template'`
- `id: 'channel'`
- `id: 'state'`
- `id: 'variables'`

### 5. Restructure `_CommunicationsListPanel` to remove the embedded `_PanelSelector` — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

- The `_CommunicationsListPanel` currently wraps content with a `_PanelSelector` + `AppWorkspaceDetailPanel`. After moving the tab strip to the parent content widget, simplify `_CommunicationsListPanel` to only render the table or inbox panel for the active panel — remove all `_PanelSelector` references.
- If `_CommunicationsListPanel` becomes trivially thin (just a switch), inline it into the parent.

### 6. Wire the "New Conversation" action — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

- Ensure a `_openNewConversation` method exists in `_CommunicationsWorkspaceContentState`:

```dart
Future<void> _openNewConversation(BuildContext context, WidgetRef ref) async {
  final CommunicationsWorkspaceController controller = ref.read(
    communicationsWorkspaceControllerProvider.notifier,
  );
  await showAppDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CommunicationsNewConversationDialog(
      onSearchStaff: controller.searchStaff,
      onSubmit: controller.createConversation,
    ),
  );
}
```

- Import `CommunicationsNewConversationDialog` if not already imported:

```dart
import 'package:hosspi_hms/features/communications/presentation/widgets/communications_new_conversation_dialog.dart';
```

### 7. Ensure proper URL synchronization follows Reception pattern — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

The existing `_syncRoute` method in `_CommunicationsWorkspaceContentState` already handles URL updates when state changes. Verify it continues to work correctly after the tab strip refactor. No functional changes needed — just ensure the `_routeSubscription` listener still fires when `applyPanel` is called from the new `AppTabStrip.onTabTapped`.

### 8. Add `alwaysVisible: true` to the first column in each table — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

Matching the Reception pattern where the primary identifying column has `alwaysVisible: true`:

- `_NotificationsTable` → first column (alert) gets `alwaysVisible: true`
- `_DeliveriesTable` → first column (notification) gets `alwaysVisible: true`
- `_TemplatesTable` → first column (template) gets `alwaysVisible: true`

### 9. Add `shrinkWrap: true` and `physics: NeverScrollableScrollPhysics()` to all `AppListTable` instances — File: `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart`

This matches the Reception pattern where tables are embedded within a scrollable parent:

```dart
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
```

Only add if the tables are within a `Column` inside a scrollable parent. Check: the tables are inside `_CommunicationsListPanel` which is in the `AppWorkspace` body. If `AppWorkspace` wraps content in a scroll view, add these. If not, skip this step to avoid layout issues.

**Decision rule:** Read `AppWorkspace.build()` — if the `body` parameter is placed inside a `SingleChildScrollView` or `ListView`, add `shrinkWrap: true` and `physics: const NeverScrollableScrollPhysics()`. Otherwise, do NOT add them.

### 10. Update tests — File: `frontend/test/features/communications/presentation/communications_workspace_controller_test.dart`

- Verify existing tests still compile and pass after the UI refactor. The controller tests should be unaffected since no controller logic changed.
- If any test references `_PanelSelector` or `AppWorkspaceOptionToggle` in widget tests, update to test `AppTabStrip` instead.

## Shared Components — MUST Reuse

Do NOT create new implementations of these. Import and use them directly:

| Component | Import Path | Usage |
|-----------|-------------|-------|
| `AppTabStrip` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Replace `AppWorkspaceOptionToggle` for panel navigation |
| `AppTabItem` | `package:hosspi_hms/shared/components/app_tab_strip.dart` | Tab definition model for `AppTabStrip` |
| `AppListTable<T>` | `package:hosspi_hms/shared/components/components.dart` | Data tables (already used — add storage keys) |
| `AppListTableSearch<T>` | `package:hosspi_hms/shared/components/components.dart` | Search bar configuration (already used) |
| `AppListTableColumnVisibilityController<T>` | `package:hosspi_hms/shared/components/components.dart` | Column visibility (already used — ensure storage keys) |
| `AppWorkspace` | `package:hosspi_hms/shared/layout/layout.dart` | High-level workspace layout (keep using) |
| `AppWorkspaceDetailPanel` | `package:hosspi_hms/shared/layout/layout.dart` | Detail panel wrapper (keep using) |
| `AppWorkspaceStatePanel` | `package:hosspi_hms/shared/layout/layout.dart` | Empty/loading states (keep using) |
| `AppButton.primary` | `package:hosspi_hms/shared/components/components.dart` | Primary action button next to tabs |
| `AppWorkspaceStatusBadge` | `package:hosspi_hms/shared/layout/layout.dart` | Status badges in tables (already used) |
| `showAppDialog` | `package:hosspi_hms/shared/components/components.dart` | Dialog launcher (already used) |

## Files to Create

No new files need to be created. All changes are modifications to existing files.

## Files to Modify

| File Path | Changes |
|-----------|---------|
| `frontend/lib/features/communications/presentation/pages/communications_workspace_page.dart` | Replace `_PanelSelector`/`AppWorkspaceOptionToggle` with `AppTabStrip`; add primary action button; add column IDs and storage keys; add `alwaysVisible` to first columns; restructure `_CommunicationsListPanel` |

## Files to Delete (if any)

None. All existing files are retained.

## Cleanup: Remove Stale Code

After the refactor, the agent MUST remove all dead/stale code left behind:

- [ ] Delete the `_PanelSelector` widget class entirely from `communications_workspace_page.dart`.
- [ ] Remove the import of `AppWorkspaceOptionToggle` if it becomes unused (check — it's imported via `package:hosspi_hms/shared/layout/layout.dart` barrel, so the import itself may stay but verify no direct usage remains).
- [ ] Remove unused imports across all modified files.
- [ ] Run `dart analyze` to catch any remaining unreferenced declarations and remove them.
- [ ] Verify no test files reference the deleted `_PanelSelector` widget — update or remove stale tests.

List every file and symbol removed in a "Cleanup Summary" section at the end of the implementation.

## Database Migrations

No database migrations required — schema unchanged. This refactoring is purely a UI-layer restructuring. The entities, DTOs, repository, and API endpoints remain identical.

## Responsive Design Requirements

- **Desktop (≥1024px):** Full tab strip with all panel labels and counts visible. Primary action button visible alongside tabs. Tables show all columns. Inbox shows split-panel (conversation list + thread view side-by-side).
- **Tablet (600–1023px):** Tab strip wraps if needed (it uses `Wrap` internally). Tables may hide optional columns via column visibility. Inbox shows conversation list only (thread replaces list on selection).
- **Mobile (<600px):** Tab strip scrolls horizontally or wraps. Tables use `mobileItemBuilder` (already implemented). Primary action button may move below tabs or shrink. Inbox shows conversation list only; selecting opens thread full-screen.

The breakpoint utility used is `AppBreakpoints` from `package:hosspi_hms/core/responsive/app_breakpoints.dart`. The `AppTabStrip` widget already handles responsive wrapping internally via `Wrap`.

## Verification Steps

After implementation, the agent MUST run these commands and confirm they pass:

```bash
# Format
dart format .

# Analyze
dart analyze --fatal-infos

# Run tests related to this screen
flutter test test/features/communications/

# Run shared component tests to ensure no regressions
flutter test test/shared/
```

## Testing Requirements

Write or update these tests:

- [ ] Tab navigation: switching tabs via `AppTabStrip` calls `controller.applyPanel` with the correct panel
- [ ] Tab counts: each tab label displays the correct count from state
- [ ] Primary action visibility: "New Conversation" button only shows on inbox tab when user has write permission
- [ ] Deep linking: navigating to `/communications?panel=notifications` renders the Notifications tab selected
- [ ] Table data: each tab displays the correct filtered dataset (unchanged behavior)
- [ ] Search: typing in the search bar filters table rows (unchanged behavior)
- [ ] Filter dialog: filter button opens the filter UI and applies filters (unchanged behavior)
- [ ] Responsive layout: inbox panel switches between split-view and single-panel at breakpoint
- [ ] No regressions: existing messaging, notification read/unread, and template viewing still work

## Acceptance Criteria

The refactor is complete when ALL of the following are true:

- [ ] The panel selector uses `AppTabStrip` (not `AppWorkspaceOptionToggle`)
- [ ] Each tab label includes its item count in parentheses (matching Reception: `"Label (N)"`)
- [ ] The "New Conversation" primary action button appears next to tabs on the inbox tab (only for users with `communicationsWrite` permission)
- [ ] Tab switching updates the URL panel query parameter
- [ ] Deep linking to a specific panel URL renders the correct tab as selected
- [ ] All `AppListTable` instances have `columnVisibilityStorageKey` and `columnWidthStorageKey`
- [ ] All table columns have explicit `id` fields
- [ ] Primary identifying columns have `alwaysVisible: true`
- [ ] No shared component is re-implemented — only imported and used
- [ ] The inbox messaging panel is preserved with its split-panel responsive layout
- [ ] All old `_PanelSelector` / `AppWorkspaceOptionToggle` code is removed
- [ ] `dart analyze` reports no new issues
- [ ] All tests pass
