# Subscriptions Workspace Navigation and Overview

Refine the subscriptions workspace so primary tabs, create actions, denied-module access, and overview analytics match the intended operator workflow—without regressing existing worklists, mutations, RBAC, or deep links.

## Context

Current UI (`frontend/lib/features/subscriptions`):

- Top tabs map to `SubscriptionPanel`: Overview, Plans (`catalog`), Subscriptions (`operations`), Invoices (`billing`), Licenses (`governance`).
- Plans nests **Plans** + **Modules**; Subscriptions nests **Subscriptions** + **Module subscriptions**.
- **Denied modules** is a shared summary chip that applies queue `module_blocked` on module-subscriptions; it appears across panels.
- Create actions (**Create plan**, **New subscription**, **Assign module**, **Add license**) mount on `AppTabStrip` via `AppTabToolbarPrimary`, not on the worklist search bar.
- Worklists already expose Search → Filters → Settings → Export; `AppListTable` places caller `trailingActions` after Export.
- Overview shows three clickable cohort KPI cards; usage and recommendations render only when data/permissions allow. Summary metrics and denied-module counts already exist in the workspace API.
- Reuse `shared/dashboard` chart widgets, theme tokens (light/dark), existing atom permissions in `subscriptions_access.dart`, and workspace query/URL contracts.

## Requirements

1. **Top-level tabs.** Present these authorized primary tabs, in order: Overview, Plans, Modules, Subscriptions, Invoices, Licenses, Denied modules. Preserve deep-link compatibility for existing `panel`/`resource`/`queue` values via redirects or aliases where enums change.
2. **Plans tab.** Show only the subscription-plans worklist. Remove the nested Plans/Modules resource strip under Plans.
3. **Modules tab.** Promote the modules catalog to its own primary tab (same read-only catalog behavior as today’s nested Modules resource; no create primary).
4. **Subscriptions tab.** Keep nested resource tabs: Subscriptions | Module subscriptions. Behavior, columns, dialogs, and permissions stay unchanged except for create-action placement (req 6).
5. **Denied modules tab.** Replace the shared **Denied modules** summary chip with a dedicated primary tab that lists entitlement-denied module subscriptions (same data as today’s `module_blocked` / eligibility-denied queue). Show empty, loading, and error states. Omit the chip from all other panels. Keep other non-denied queue chips (pending changes, past due, expiring licenses, approaching limits) unless a chip would duplicate this tab.
6. **Create actions in search bar.** Remove tab-strip primaries for Create plan, New subscription, Assign module, and Add license. Mount each as a worklist `trailingActions` control after Export on its owning table: Plans → Create plan; Subscriptions → New subscription; Module subscriptions → Assign module; Licenses → Add license. Gate with the same atom permissions as today; omit when unauthorized (do not disable). Invoices and Modules remain without a create primary.
7. **Overview enrichment.** Keep the three clickable cohort KPI cards. Below them, add overview content that reuses existing summary/overview payload fields: at least one distribution or comparison chart (e.g. tenant cohorts and/or plan-tier mix) and short status sections for usage limits, billing/license attention, and recommendations when data exists. Charts and sections must use theme tokens and remain usable in light and dark mode. When chart data is empty, show a compact empty state; do not invent series.
8. **Filters and Settings.** Keep advanced Filters and table Settings on every worklist. Scope filter groups to the active resource; ensure Filters and Settings dialogs use design-system surfaces, spacing, and typography with clear apply/reset (filters) and persist column visibility/widths (settings). No clipped controls on mobile, tablet, or desktop.
9. **Theme.** All new and relocated chrome (tabs, chips, charts, dialogs, trailing actions) must render correctly in light and dark themes via theme tokens—no hardcoded light-only colors.
10. **Authorization and sync.** Backend RBAC/ABAC remains authoritative. Unauthorized tabs, rows, and actions must not render. After mutations, refresh list/overview/summary state so counts and graphs stay consistent.

### Optional enhancements

- Deep-link badge count on the Denied modules tab from `summary.denied_modules`.
- Overview sparkline/trend only if the API already returns time-series points; do not add a new analytics backend in this pass.

## Constraints

- Follow `prompts/.cursor/prompt.mdc`, `.cursor/access/subscriptions.mdc`, and existing subscriptions atom maps.
- Reuse workspace controller, DTOs, routes, dialogs, `AppListTable`, `AppTabStrip`, and dashboard chart components; no unrelated refactors.
- Preserve create/edit/assign/license dialogs and their validation; only relocate entry points.
- Do not recreate removed `screens/` inventories.

## Acceptance Criteria

1. Authorized users see primary tabs Overview → Plans → Modules → Subscriptions → Invoices → Licenses → Denied modules; unauthorized tabs are absent.
2. Plans has no nested Modules strip; Modules is reachable only as its own primary tab; Subscriptions still nests Subscriptions | Module subscriptions.
3. Denied modules tab shows denied module-subscription rows; the Denied modules chip no longer appears on other panels.
4. Create plan / New subscription / Assign module / Add license appear after Export on the correct worklist and are absent from the tab strip; unauthorized users do not see them.
5. Overview still opens cohort dialogs from KPI cards and shows at least one chart plus available usage/attention/recommendation content; empty chart data shows an empty state.
6. Filters and Settings open polished dialogs on every worklist; light and dark themes remain readable with no overflow/clipping at representative viewports.
7. Existing mutations and deep links continue to work; post-mutation overview/list counts update without a full app restart.

## Relevant Files

- `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
- `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_table_columns.dart`
- `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`
- `frontend/lib/features/subscriptions/presentation/subscriptions_access.dart`
- `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/dashboard/dashboard_charts_row.dart`
- `backend/src/modules/subscriptions-workspace/`
- `frontend/test/features/subscriptions/presentation/`

## Verification

- Update/extend tab, permissions, and workspace page tests: unauthorized create actions and Denied modules chip absent; authorized trailing actions and Denied modules tab present; Modules is a primary tab; Plans has no nested Modules strip.
- Manual: light/dark Overview charts; Filters/Settings dialogs; create flows from search-bar actions; Denied modules tab vs former chip; mobile/tablet/desktop layout.
- Confirm post-create/assign/license sync of worklist and overview counts.
