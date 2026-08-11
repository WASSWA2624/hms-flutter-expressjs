# Radiology workspace UI inventory

Source: `tabs-lister/11-radiology.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `RadiologyWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/radiology` (`AppRoutes.radiology`)  
**Page:** `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (+ `.print.dart`, `.configurations.dart`, `.detail_cells.dart`)  
**Access:** `frontend/lib/features/radiology/presentation/radiology_access.dart`  
**Sections enum:** `RadiologyDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `worklist` | `worklist` | `work` | [01-worklist.md](01-worklist.md) |
| `reporting` | `reporting` | `reports`, `draft` | [02-reporting.md](02-reporting.md) |
| `allOrders` | `all` | `all_orders`, `all-orders`, `history`, `order-history`, `order_history` | [03-all-orders.md](03-all-orders.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [04-follow-ups.md](04-follow-ups.md) |

Helpers: `_sectionToQueryValue` / `_sectionFromQuery` in `radiology_workspace_page.dart`. Stages: `WORKLIST` / `REPORTING` / `HISTORY`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.print.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart`
- `frontend/lib/features/radiology/presentation/radiology_access.dart`
- `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `frontend/lib/features/radiology/presentation/widgets/radiology_next_action_cell.dart`
- `frontend/lib/shared/follow_up/follow_up_worklist_panel.dart` (**reused**)
- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart` (**reused**)
- `frontend/lib/shared/radiology_catalog/radiology_catalog_dialogs.dart` (**reused**)
- `frontend/test/features/radiology/`
