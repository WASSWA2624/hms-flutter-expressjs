# Reports workspace UI inventory

Source: `tabs-lister/18-reports.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `ReportsWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/reports` (`AppRoutes.reports`)  
**Page:** `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`  
**Access:** `frontend/lib/features/reports/presentation/reports_access.dart`  
**Panels enum:** `ReportsWorkspacePanel`

## Workspace panels (order)

Panel navigation is **not** `AppTabStrip` — Advanced filters group key `'panel'` switches panels. Inventory still treats each panel as a tab-equivalent file.

| Enum | `serverValue` | File |
| --- | --- | --- |
| `overview` | `overview` | [01-overview.md](01-overview.md) |
| `catalog` | `catalog` | [02-catalog.md](02-catalog.md) |
| `delivery` | `delivery` | [03-delivery.md](03-delivery.md) |
| `dashboards` | `dashboards` | [04-dashboards.md](04-dashboards.md) |
| `monitor` | `monitor` | [05-monitor.md](05-monitor.md) |
| `activity` | `activity` | [06-activity.md](06-activity.md) |
| `audit` | `audit` | [07-audit.md](07-audit.md) |
| `phi` | `phi` | [08-phi.md](08-phi.md) |
| `processing` | `processing` | [09-processing.md](09-processing.md) |

Helpers: `ReportsWorkspacePanel.serverValue` in `reports_entities.dart`. Deep-link today is only `?dataset=` (Catalog prefilter)—no `panel`/`section` URL sync.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/reports/presentation/pages/reports_workspace_page.dart`
- `frontend/lib/features/reports/presentation/reports_access.dart`
- `frontend/lib/features/reports/presentation/reports_role_tailoring.dart`
- `frontend/lib/features/reports/domain/entities/reports_entities.dart`
- `frontend/lib/features/reports/presentation/controllers/reports_workspace_controller.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_workspace_table_helpers.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_dashboard.dart`
- `frontend/lib/features/reports/presentation/widgets/reports_overview_shortcut_dialogs.dart`
- `frontend/lib/features/reports/presentation/widgets/pharmacy_reporting_filters_dialog.dart`
- `frontend/lib/features/reports/presentation/widgets/pharmacy_reporting_report_dialog.dart`
- `frontend/test/features/reports/`
