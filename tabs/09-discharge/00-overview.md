# Discharge workspace UI inventory

Source: `tabs-lister/09-discharge.md` · Code base date: 2026-08-12

## Context

Catalog of every visible / reachable UI atom on `DischargeWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/discharge` (`AppRoutes.discharge`)  
**Page:** `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`  
**Access:** `frontend/lib/features/discharge/presentation/discharge_access.dart`  
**Sections enum:** `DischargeDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `all` | `all` | — | [01-all.md](01-all.md) |
| `planned` | `planned` | — | [02-planned.md](02-planned.md) |
| `pendingClearance` | `pending` | `pending_clearance`, `pending-clearance`, `pendingclearance` | [03-pending-clearance.md](03-pending-clearance.md) |
| `completed` | `completed` | `discharged` | [04-completed.md](04-completed.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [05-follow-ups.md](05-follow-ups.md) |

Helpers: `_sectionToQueryValue` / `_sectionFromQuery` on `DischargeWorkspacePage` (enum in `discharge_entities.dart`).

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/discharge/presentation/pages/discharge_workspace_page.dart`
- `frontend/lib/features/discharge/presentation/discharge_access.dart`
- `frontend/lib/features/discharge/domain/entities/discharge_entities.dart`
- `frontend/lib/features/discharge/presentation/controllers/discharge_workspace_controller.dart`
- `frontend/lib/features/discharge/presentation/widgets/discharge_planning_dialog.dart`
- `frontend/lib/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart`
- `frontend/lib/features/discharge/presentation/widgets/discharge_clearance_dialog.dart`
- `frontend/lib/features/discharge/presentation/widgets/discharge_clearance_tile.dart`
- `frontend/lib/features/discharge/presentation/discharge_*_billing_inventory.dart`
- `frontend/test/features/discharge/`
