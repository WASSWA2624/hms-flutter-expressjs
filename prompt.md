# Simplify the Reception Desk Page Layout

## Objective

Flatten the Reception desk workspace page (`/reception`) by removing the dedicated header title row, the global actions overflow menu, and the external search bar. Replace the `ChoiceChip` section selector with a standard `TabBar`. The primary action ("Register patient") moves to the trailing end of the tab row.

---

## Current State

**File:** `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`

The page currently renders (top-to-bottom):

1. **`AppWorkspace` wrapper** — title `l10n.receptionTitle` ("Reception desk") with `AppRouteIcons.reception`, rendered via `AppWorkspaceHeader`.
2. **`AppWorkspaceToolbar`** (via `appWorkspaceToolbarWithLabels`) with `showGlobalActions: true` (default) — producing global actions: Refresh, Request maintenance (`AppGlobalHousekeepingRequestAction`), Report equipment fault (`AppGlobalFaultReportAction`), and a Notifications summary submenu (`_ToolbarNotificationsSubmenu`). These collapse into the three-dot overflow menu on narrower widths. The toolbar also includes secondary actions: "Schedule appointment" and "Start walk-in".
3. **`ChoiceChip` section selector** — a `Wrap` of `ChoiceChip` widgets for `ReceptionDeskSection.values`: Appointments, Desk queue, Active visits, Payment gate.
4. **`AppTextField` search bar** — a standalone text field (`_searchController`) with debounced client-side filtering, placed between the section chips and the card list.
5. **`_ReceptionDeskCard` list** — a `Column` of patient/appointment/queue cards, filtered by the selected section and search query. This is **not** an `AppListTable`; it is a custom card layout.
6. **Primary action** — `AppButton.primary` ("Register patient") gated by `receptionFrontDeskWriteRequirement`, passed as `primary` into the toolbar config.

### Toolbar config (current)

```dart
toolbar: appWorkspaceToolbarWithLabels(
  l10n,
  summaryNotifications: _summaryNotifications(context, state),
  primary: AppAccessActionGate(
    requirement: receptionFrontDeskWriteRequirement,
    builder: (context, isAllowed) => AppButton.primary(
      label: l10n.receptionRegisterPatientAction,
      leadingIcon: Icons.person_add_alt_1_outlined,
      enabled: isAllowed,
      onPressed: isAllowed ? () => _openRegisterPatient() : null,
    ),
  ),
  secondary: [
    /* Schedule appointment button */,
    /* Start walk-in button */,
  ],
  onRefresh: () async { ... },
  isRefreshing: state.isRefreshingAppointments || ...,
),
```

---

## Target Design

### 1. Remove the `AppWorkspace` header title row

- Remove the `title` / `leadingIcon` display ("Reception desk" heading and its icon). The sidebar navigation already identifies the section.
- Keep `AppWorkspace` as the layout wrapper for padding/scroll/responsive behaviour, but suppress the header. Alternatively, replace with `ResponsivePage` + `Column` if cleaner.

### 2. Remove the global actions overflow menu

- Set `showGlobalActions: false` in the toolbar config.
- This eliminates: Refresh, Request maintenance, Report equipment fault, and the Notifications summary submenu from the toolbar overflow.
- **Keep Refresh** — wire it through a pull-to-refresh gesture or an inline refresh indicator within the card list, not the global toolbar overflow.

### 3. Replace the `ChoiceChip` row with the app's standard `TabBar` component

- Replace the `Wrap` of `ChoiceChip` widgets with a `TabBar` / `Tab` widget (or `AppTabStrip` if that is the app's standard component — it is already used in `SettingsAccountSection` and `_SettingsAccordion`).
- Tab items remain: Appointments, Desk queue, Active visits, Payment gate (from `ReceptionDeskSection.values`).
- The selected tab must continue to drive `setState(() => _section = section)` and reflect the `section` query parameter in the URL for deep-linking.

### 4. Move the primary action button to the right of the tab row

- Position the "Register patient" `AppButton.primary` (gated by `receptionFrontDeskWriteRequirement`) aligned to the trailing end of the tab bar row.
- Layout: `Row [ Expanded(TabBar/AppTabStrip), SizedBox(spacing), PrimaryAction ]`.
- Secondary actions ("Schedule appointment", "Start walk-in") can either:
  - Remain in a lightweight overflow on the tab row, or
  - Move into contextual card-level actions, depending on UI simplicity goals.

### 5. Remove the standalone `AppTextField` search bar

- Delete the standalone `AppTextField` widget that currently sits between the section chips and the card list.
- Move the search input **into** the card list header area — either as a compact search bar above the first card, or as a collapsible/toggle search field triggered by a search icon in the tab row.
- Continue using the same debounced client-side filtering logic via `_searchController`.

### 6. Remove the `AppWorkspaceToolbar` entirely (optional)

- If the toolbar only served global actions and the primary button (which now lives in the tab row), remove the `toolbar` parameter from `AppWorkspace` entirely.
- If secondary actions remain toolbar-hosted, keep a minimal toolbar with `showGlobalActions: false`.

---

## Resulting Widget Tree (Target)

```
AppWorkspace (no visible header) / ResponsivePage
  └── Column
        ├── Row (tabs + primary action)
        │     ├── Expanded(AppTabStrip / TabBar [Appointments, Desk queue, Active visits, Payment gate])
        │     └── AppAccessActionGate → AppButton.primary ("Register patient")
        ├── Compact search bar (optional, toggleable)
        └── _ReceptionDeskCard list (filtered by section + search)
```

---

## Files to Modify

| File | Change |
|---|---|
| `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart` | Remove `AppWorkspace` title/header. Set `showGlobalActions: false` or remove toolbar. Replace `ChoiceChip` `Wrap` with `AppTabStrip` / `TabBar`. Move "Register patient" button to trailing end of tab row. Remove standalone `AppTextField` search bar; integrate search into card list header. |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | No changes needed (just pass `showGlobalActions: false` from the page, or omit the toolbar entirely). |

---

## Technical Constraints

- **State management**: continue using `opdWorkspaceControllerProvider` (Riverpod) for data. Section switching, search, and refresh must still work via the controller and local `StatefulWidget` state.
- **URL-driven state**: the `section` query parameter must still reflect the selected tab. Deep-linking to `/reception?section=queue` must select the correct tab.
- **Client-side search**: the search field uses debounced local filtering (250ms) via `_searchController`. Retain this behaviour wherever the search field is relocated.
- **Responsiveness**: the tab bar must scroll or wrap on smaller screens. The primary action button must remain accessible on mobile. The card list must remain fully responsive.
- **Access control**: the "Register patient" button and secondary actions must remain gated by `receptionFrontDeskWriteRequirement` via `AppAccessActionGate`.
- **No regressions**: Register patient, Schedule appointment, Start walk-in, appointment check-in, queue prioritisation, flow actions, patient editing, insurance capture, and all section views must continue to function identically.
- **Accessibility**: tabs must be keyboard-navigable (arrow keys, Enter/Space). The search field must have an appropriate `semanticLabel`. Respect `reduceMotion` for any transitions.
- **Consistent pattern**: this simplification follows the same pattern applied to the Admin Access page (`prompt1.md`). Use the same component choices (`AppTabStrip` vs. `TabBar`) and layout approach for cross-page consistency.
