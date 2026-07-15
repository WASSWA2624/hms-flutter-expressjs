# Simplify the Admin Access Page Layout

## Objective

Flatten the Admin Access workspace page (`/admin/access`) by removing the dedicated header, the global actions overflow menu, and the external search/filter bar. The page should use only the `AppListTable` built-in search bar and rely on a cleaner toolbar with contextual actions.

---

## Current State

**File:** `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart`

The page currently renders (top-to-bottom):

1. **`AppWorkspace` header** — title "Users and access" with `AppWorkspaceTitleIcon`, rendered by `AppWorkspaceHeader`.
2. **`AppWorkspaceToolbar`** (via `appWorkspaceToolbarWithLabels`) with `showGlobalActions: true` — producing global actions: Refresh, Request maintenance (`AppGlobalHousekeepingRequestAction`), Report equipment fault (`AppGlobalFaultReportAction`), and Notifications summary (`_ToolbarNotificationsSubmenu`). These collapse into the overflow (three-dot) menu on smaller widths.
3. **`_PanelSelector`** — a `Wrap` of `FilterChip` widgets for panels: Overview, User directory, Roles, Permissions, Module entitlements, Pending registrations, Demo accounts.
4. **`_FiltersBar`** — an `AppContentPanel` wrapping an `AppTextField` for server-side search (plus a status dropdown when viewing users).
5. **`_WorklistPanel`** — an `AppContentPanel` wrapping `AppListTable<AccessAdminItem>` (paginated, server-side).
6. **`_primaryAction`** — an `AppButton.primary` ("Create role" / "Create user") passed into the toolbar config.

---

## Target Design

### 1. Remove the `AppWorkspace` header title row

- Remove the `title` display (the "Users and access" heading and its icon) from the page. The page no longer needs a visible title bar since the sidebar navigation already identifies the section.
- Keep `AppWorkspace` as the layout wrapper if needed for padding/scroll/responsive behaviour, but set it up so no title/header renders, or replace with a simpler `ResponsivePage` + `Column` if cleaner.

### 2. Remove the global actions overflow menu

- Set `showGlobalActions: false` in the toolbar config (or remove the toolbar entirely if it only served global actions).
- This eliminates: Refresh, Request maintenance, Report equipment fault, and the Notifications submenu from the toolbar/overflow.
- **Keep** the Refresh capability if needed — but wire it through `AppListTable`'s built-in refresh mechanism or a pull-to-refresh, not the global toolbar action.

### 3. Replace the `_PanelSelector` (FilterChip row) with the app's standard `TabBar` component

- Replace the `Wrap` of `FilterChip` widgets with the standard Material `TabBar` / `Tab` widget (or the app's custom tab component if one exists in `shared/components/`).
- Tab items remain the same: Overview, User directory, Roles, Permissions, Module entitlements, Pending registrations, Demo accounts.
- The selected tab should continue to drive `controller.applyPanel(panel)` and reflect the `panel` query parameter in the URL.

### 4. Move the primary action button to the right of the tab row

- Position the contextual action button (`AppButton.primary` — "Create role", "Create user", or nothing) aligned to the trailing end of the tab bar row.
- This creates a single horizontal strip: `[Tabs .......................... Action Button]`.

### 5. Remove the standalone `_FiltersBar` and its `AppContentPanel` wrapper

- Delete the `_FiltersBar` widget entirely.
- The server-side search text field is no longer needed as a separate bar above the table.

### 6. Remove the `AppContentPanel` wrapper around the table

- The `_WorklistPanel` currently wraps `AppListTable` inside an `AppContentPanel` (which adds padding and a border/card). Remove this wrapper so the table renders directly without extra chrome.

### 7. Use `AppListTable`'s built-in search bar

- Enable the `search` parameter on `AppListTable<AccessAdminItem>` by providing an `AppListTableSearch<AccessAdminItem>(...)` config:
  - `controller`: a `TextEditingController` for the search input.
  - `semanticLabel`: appropriate label (e.g. `l10n.accessAdminSearchLabel`).
  - `matcher`: a function that filters `AccessAdminItem` by the query string (match against name, ID, details, etc.).
- If the table must remain server-side paginated (i.e. search hits the API), continue using `onFieldSubmitted` → `controller.applySearch(value)` but embed the search field within the table's header row using `AppListTable`'s `search` or `searchListenable`/`searchMatcher` parameters so it renders inside the table chrome rather than externally.
- The table's built-in search bar should also include any necessary filters (e.g. the user status dropdown) and settings controls.

---

## Resulting Widget Tree (Target)

```
ResponsivePage / AppWorkspace (no visible header)
  └── Column
        ├── Row (tabs + action)
        │     ├── Expanded(TabBar [...panels...])
        │     └── _primaryAction (AppButton.primary, contextual)
        └── AppListTable<AccessAdminItem>
              ├── Built-in search bar (with filters + settings)
              └── Data rows (paginated)
```

---

## Files to Modify

| File | Change |
|---|---|
| `frontend/lib/features/access_admin/presentation/pages/access_admin_workspace_page.dart` | Remove `AppWorkspace` title/header, set `showGlobalActions: false` or remove toolbar, replace `_PanelSelector` with `TabBar`, remove `_FiltersBar`, unwrap `AppContentPanel` from table, enable `AppListTable` built-in search. Move primary action to tab row. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | No changes needed (just pass `showGlobalActions: false` from the page). |

---

## Technical Constraints

- **State management**: continue using `accessAdminWorkspaceControllerProvider` (Riverpod). Panel switching, search, and pagination must still work via the controller.
- **URL-driven state**: the `panel` query parameter must still reflect the selected tab. Deep-linking to `/admin/access?panel=roles` must select the correct tab.
- **Server-side search**: if `AppListTable`'s built-in search is wired to server-side filtering (via `controller.applySearch`), ensure debounce and loading states are handled.
- **Responsiveness**: the tab bar must scroll or wrap on smaller screens. The action button must remain accessible.
- **No regressions**: Create role/user dialogs, pagination, row selection/navigation, and all panel views must continue to function identically.
- **Accessibility**: tabs must be keyboard-navigable (arrow keys, Enter/Space). Maintain focus management.
