# HR workspace UI inventory

Source: `tabs-lister/17-hr.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `HrWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/hr` (`AppRoutes.hr`)  
**Page:** `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`  
**Access:** `frontend/lib/features/hr/presentation/hr_access.dart`  
**Sections enum:** `HrDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `staffDirectory` | `staff` | `staff-directory`, `directory` | [01-staff-directory.md](01-staff-directory.md) |
| `positions` | `positions` | `staff-positions`, `position` | [02-positions.md](02-positions.md) |
| `shiftRoster` | `shift-roster` | `shift`, `roster`, `roster-drafts`, `shifts` | [03-shift-roster.md](03-shift-roster.md) |
| `leaveRequests` | `leave-requests` | `leave`, `leaves` | [04-leave-requests.md](04-leave-requests.md) |
| `swapRequests` | `swap-requests` | `swap`, `swaps` | [05-swap-requests.md](05-swap-requests.md) |
| `unassignedShifts` | `unassigned-shifts` | `unassigned`, `overdue`, `overdue-shifts` | [06-unassigned-shifts.md](06-unassigned-shifts.md) |
| `payroll` | `payroll` | `payroll-drafts` | [07-payroll.md](07-payroll.md) |
| `access` | `access` | `roles`, `permissions` | [08-access.md](08-access.md) |

Helpers: `HrDeskSection.routeQueryValue` / `fromQuery` / `fromQueue` in `hr_entities.dart`. Queue deep-links (`HrQueue.value`) can override section when present.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_dialog_actions.dart`
- `frontend/lib/features/hr/presentation/hr_access.dart`
- `frontend/lib/features/hr/domain/entities/hr_entities.dart`
- `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_workspace_dialogs.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_access_dialogs.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_staff_print_helpers.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_position_print_helpers.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_roster_print_helpers.dart`
- `frontend/test/features/hr/`
