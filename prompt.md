# Refactor Subscriptions Page: Replace Toolbar Overflow Menu with Inline Tab Bar

## Objective

Replace the current **"Overview" overflow dropdown menu** (containing Plans, Subscriptions, Invoices, Licenses, Notifications) and the page title header row with a **horizontal tab bar** that serves as the primary navigation between subscription panels. Simultaneously flatten the worklist panel by removing its outer `AppWorkspaceDetailPanel` wrapper.

---

## Current Structure (to be changed)

The page currently renders:

1. **`AppWorkspace` header** — title "Subscriptions" + icon + toolbar with an "Overview" overflow button.
2. **Toolbar overflow menu** (`overflowSections`) — a "Views" section listing `SubscriptionPanel` values as `AppButton` items (Plans, Subscriptions, Invoices, Licenses) plus a Notifications section.
3. **Body** — a `Column` with:
   - `_SubscriptionOverviewPanel` (metric cards row)
   - `_SubscriptionsWorklistPanel` wrapped in `AppWorkspaceDetailPanel` (titled panel containing the search bar + `AppListTable`)

---

## Target Structure

1. **Remove** the `AppWorkspace` title row and the `AppWorkspaceHeader` that renders the "Subscriptions" title, icon, and toolbar overflow button.
2. **Replace** it with a **horizontal tab bar** placed at the top of the workspace body. Each tab corresponds to a `SubscriptionPanel` value:
   - Plans (`catalog`)
   - Subscriptions (`operations`)
   - Invoices (`billing`)
   - Licenses (`governance`)
   - Notifications (use existing notification count badge; keep the `>` chevron for navigation to notification details if applicable)
   - Optionally retain an "Overview" tab if it maps to a distinct panel view.
3. **Remove** the `_SubscriptionsWorklistPanel`'s outer `AppWorkspaceDetailPanel` wrapper (the bordered card with the "Subscriptions" sub-title and icon). The search bar and table should render directly in the body column without an enclosing card/panel container.
4. **Preserve** the `_SubscriptionOverviewPanel` (metric cards) — it stays above the table.

---

## Behaviour

- **Active tab** is determined by `state.query.panel`. Tapping a tab calls `controller.applyPanel(panel)` (same logic currently in the overflow buttons).
- **Disabled state**: tabs should be non-interactive while `state.isRefreshing` is true.
- **Primary action button** (e.g. "Activate subscription", "Create plan") remains accessible — position it as a trailing action aligned to the right of the tab bar row, or below it if space is insufficient.
- **Refresh action** and **summary notification cards** (Active plans, Not subscribed, Closed subscriptions, Past due) remain visible — keep them in the metric cards row (`_SubscriptionOverviewPanel`).

---

## UX Details

- Use `TabBar` / `Tab` (or a custom chip/segmented-button row consistent with the app's design system) for the panel switcher.
- Active tab should have a clear selected indicator (primary colour underline or filled background) matching the app's existing `AppButtonVariant.primary` styling.
- The tab bar must be horizontally scrollable on narrow viewports (wrap in a `SingleChildScrollView` with `scrollDirection: Axis.horizontal` if needed).
- Notification badge count (`9 >` as shown in the screenshot) should render as a trailing badge on the Notifications tab.

---

## Technical Constraints

- **Scope**: changes are limited to `subscriptions_workspace_page.dart`. Modify the `_SubscriptionsWorkspaceContentState.build` method and `_SubscriptionsWorklistPanel`.
- **No new dependencies**: use existing Flutter/Material widgets and the app's shared component library.
- **Preserve functionality**: all existing panel switching, search, filtering, table column visibility, pagination, detail dialog opening, RBAC gating, and real-time refresh logic must remain unchanged.
- **AppWorkspace widget**: if `AppWorkspace` requires a `title`, pass an empty or minimal value but hide the rendered header — or restructure to use `AppWorkspace`'s `body` only. Do not break other pages that use `AppWorkspace`.
- **Localization**: continue using `_SubscriptionsText` constants for all labels.

---

## Summary of Removals

| Remove | Reason |
|--------|--------|
| Title row ("Subscriptions" + icon) rendered by `AppWorkspaceHeader` | Replaced by tab bar |
| "Overview" overflow dropdown button + `overflowSections` | Panels are now tabs |
| `AppWorkspaceDetailPanel` wrapping `_SubscriptionsWorklistPanel` | Flattens layout; search bar + table render directly |

## Summary of Additions

| Add | Details |
|-----|---------|
| Horizontal tab bar | One tab per `SubscriptionPanel` value, plus Notifications with badge |
| Direct search + table rendering | No enclosing panel card around the worklist |
