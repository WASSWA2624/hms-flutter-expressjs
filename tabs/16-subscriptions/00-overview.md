# Subscriptions workspace UI inventory

Source: `tabs-lister/16-subscriptions.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `SubscriptionsWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/subscriptions` (`AppRoutes.subscriptions`)  
**Page:** `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`  
**Access:** `frontend/lib/features/subscriptions/presentation/subscriptions_access.dart`  
**Panels enum:** `SubscriptionPanel`

## Desk tabs (order)

| Enum | Query `panel` | Default resource | File |
| --- | --- | --- | --- |
| `overview` | `overview` | (KPI panel; no worklist) | [01-overview.md](01-overview.md) |
| `catalog` | `catalog` | `subscription-plans` | [02-catalog.md](02-catalog.md) |
| `modules` | `modules` | `modules` | [03-modules.md](03-modules.md) |
| `operations` | `operations` | `subscriptions` (+ nested `module-subscriptions`) | [04-operations.md](04-operations.md) |
| `billing` | `billing` | `subscription-invoices` | [05-billing.md](05-billing.md) |
| `governance` | `governance` | `licenses` | [06-governance.md](06-governance.md) |
| `denied` | `denied` | `module-subscriptions` (+ `MODULE_BLOCKED` queue) | [07-denied.md](07-denied.md) |

Helpers: `SubscriptionPanel.serverValue` / `fromServer` (aliases `denied-modules`); query also accepts `resource`, `queue`, filters.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_page.dart`
- `frontend/lib/features/subscriptions/presentation/pages/subscriptions_workspace_table_columns.dart`
- `frontend/lib/features/subscriptions/presentation/subscriptions_access.dart`
- `frontend/lib/features/subscriptions/domain/entities/subscription_entities.dart`
- `frontend/lib/features/subscriptions/presentation/controllers/subscriptions_workspace_controller.dart`
- `frontend/lib/features/subscriptions/presentation/widgets/subscription_upgrade_dialog.dart`
- `frontend/lib/features/subscriptions/presentation/widgets/subscription_report_admins_dialog.dart`
- `frontend/test/features/subscriptions/`
