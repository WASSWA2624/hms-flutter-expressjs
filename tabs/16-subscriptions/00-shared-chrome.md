# Subscriptions — shared / cross-tab chrome

## Shell entry

- Route: `AppRoutes.subscriptions`
- Route entry: `subscriptionsWorkspaceRouteEntryRequirement` — ∪ `platform:admin` (`RouteAccessCatalog.subscriptionsEntry`)
- Content atoms: ∩ `subscriptions:read|write|delete` + module `subscription-controls`
- If no panels allowed: `SizedBox.shrink()`
- Fallback panel prefers `catalog` when authorized

## Page chrome

- `AsyncStateScaffold` over `subscriptionsWorkspaceControllerProvider`
  - Loading: `Loading subscriptions` / body copy
  - Title: `Subscriptions`
- Body: `ResponsivePage` + panel `AppTabStrip` + optional queue chips + overview **or** resource nested tabs + worklist
- URL: `panel`, `resource`, `queue`, search, filter params via `SubscriptionsWorkspaceQuery.location()`
- Page-level failure banner cleared; mutations use snackbars (`Subscription workspace updated.`)

## Tab strip

- Labels: Overview · Plans · Modules · Subscriptions · Invoices · Licenses · Denied modules (`_SubscriptionsText`)
- Tabs omitted when `canViewSubscriptionsPanel` fails
- Denied modules may show count when `deniedModulesCount > 0`
- Icons: dashboard / workspace_premium / view_module / verified_user / receipt_long / key / block

## Queue chips (shared)

Mounted when summary queues readable; navigate to target panel/filters (Pending changes, Past due invoices, Denied modules, Expiring licenses, Approaching limits, …). Chip gate: panel readable.

## Worklist toolbar (non-overview)

Order: **Filters → Settings → Create\* **

| Control | Notes |
| --- | --- |
| Search | `_SubscriptionsText.searchHint` |
| Filters | always on worklist; `enableDateFilter: false` (date via `date_preset` filter group when present) |
| Settings | `subscriptions_ws_<resource>` / `subscriptions_cw_<resource>` |
| Export / Print | **not** mounted on worklist |
| Create\* | Create plan / New subscription / Add license only — omitted on overview, modules, billing, denied |

Nested resource tab bar when panel has >1 resource (operations: subscriptions + module-subscriptions).

## Shared dialogs / reused

| Surface | Owner |
| --- | --- |
| Plan / subscription / license / invoice detail | Subscriptions-owned (`_openSubscriptionDetailDialog`) |
| Create/edit plan, manage modules | Subscriptions-owned |
| Upgrade | Subscriptions-owned `subscription_upgrade_dialog.dart` |
| Report / manage admins | Subscriptions-owned `subscription_report_admins_dialog.dart` |
| Payment method selectors | Subscriptions-owned widgets |
| Tenant lookups | from workspace lookups (platform catalog) |

## Feedback

- Empty: `_SubscriptionsText.emptyTitle` / `emptyBody`
- Success: `savedMessage`
- Overview cohort dialogs reuse create/edit subscription write gates
