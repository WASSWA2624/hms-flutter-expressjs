# Refactor Setup Checklist & Quick Actions in Administrative Setup Workspace

## Objective

Redesign the **Setup checklist** tab within `SettingsWorkspaceSection` (`frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart`) to reduce vertical space consumption and eliminate redundant page navigation. All interactions must reuse existing in-app infrastructure (dashboard panels, modal dialogs) instead of navigating to standalone admin pages.

---

## Current State (see attached screenshots)

- The `_SettingsChecklistPanel` renders each `SettingsChecklistItem` as a full-width row (`_SettingsChecklistRow`) with a status icon, label, and an "Open" button — 8 items occupy excessive vertical space.
- Both the "Open" button and quick-action buttons call `context.go(route)`, navigating to full pages (`AppRoutes.tenantFacilitySetup`, `AppRoutes.accessAdmin`).
- Quick actions ("Create Tenant", "Create Facility", etc.) also navigate to pages rather than opening creation dialogs.

---

## Requirements

### 1. Compact checklist layout

Replace the vertically stacked `_SettingsChecklistRow` list with a **dense, wrapping chip/button grid**. Each checklist item should render as a compact status button containing:

| Element | Position | Details |
|---------|----------|---------|
| Entity icon | Leading | Use the existing `_iconFor()` mapping for the item's icon key |
| Entity label | Centre | e.g. "Tenant", "Facility", "Ward" |
| Status indicator | Trailing or overlay | Green check when `item.completed == true`; muted/outlined circle when incomplete |

- Buttons should wrap responsively (use `Wrap` with tight spacing) so items sit side-by-side and only stack on narrow viewports.
- Tapping a checklist button triggers the **"Open" action** (see §2 below) — no separate "Open" text button.

### 2. Eliminate page navigation on "Open"

Currently `_SettingsChecklistRow.onPressed` and `_SettingsActionButton.onPressed` call `context.go(route)`. Replace this with **in-context actions**:

- **Organization entities** (Tenant, Facility, Department, Ward, Bed): instead of navigating to the `tenantFacilitySetup` page, open the relevant management panel or card **inline** — reuse the existing dashboard infrastructure already defined for these entities (tab panels, data tables, or detail cards). If these are managed via a tabbed workspace, activate the correct tab programmatically.
- **Access entities** (User, Role, Permission): instead of navigating to the `accessAdmin` page, open the relevant panel within the existing access-management workspace, or surface the appropriate card/dialog in place.
- The goal is **zero full-page navigations** from the setup checklist — the user stays on the Settings page.

### 3. Quick actions open modal dialogs

Each quick action in `_SettingsQuickActionsPanel` currently calls `context.go(route)`. Replace with dialog invocations:

| Quick Action | Expected Behaviour |
|--------------|--------------------|
| Create Tenant | Open the **create-tenant dialog** |
| Create Facility | Open the **create-facility dialog** |
| Create Department | Open the **create-department dialog** |
| Create Ward | Open the **create-ward dialog** |
| Create Bed | Open the **create-bed dialog** |
| Create User | Open the **create-user dialog** |
| Create Role | Open the **create-role dialog** |
| Create Permission | Open the **create-permission dialog** |

- Reuse existing create/edit dialog widgets already defined in the codebase for each entity. Do **not** create new standalone pages.
- After a successful creation, refresh the workspace state (`settingsWorkspaceControllerProvider`) so the checklist status updates in real time.

### 4. Remove or deprecate redundant admin pages

Audit and remove any standalone settings pages whose sole purpose is duplicated by the dashboard infrastructure now invoked from the checklist and quick actions. If a page is referenced elsewhere (deep links, bookmarks), retain the route but redirect it to the appropriate in-context panel.

---

## Technical Constraints

- **Scope**: changes should be confined to `settings_workspace_section.dart` and the entity dialog imports. Avoid restructuring unrelated features.
- **State management**: continue using `settingsWorkspaceControllerProvider` (Riverpod). Trigger `.refresh()` after any create/update action completes.
- **Reusable components**: if a new compact status-button widget is created, place it in `frontend/lib/shared/components/` for reuse.
- **Localization**: use existing `l10n` keys. Add new keys only if a label does not yet exist.
- **Responsiveness**: the chip/button grid must be fully responsive — single-column on mobile, multi-column on wider viewports.
- **Accessibility**: each button must remain focusable and activatable via keyboard (Enter/Space). Status must be conveyed via semantics, not colour alone.
- **No regressions**: all existing checklist data (completed/incomplete states, counts, priorities) and workspace functionality must continue to work unchanged.
