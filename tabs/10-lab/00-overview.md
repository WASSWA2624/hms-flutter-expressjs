# Lab workspace UI inventory

Source: `tabs-lister/10-lab.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `LabWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/lab` (`AppRoutes.lab`)  
**Page:** `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`  
**Access:** `frontend/lib/features/lab/presentation/lab_access.dart`  
**Sections enum:** `LabDeskSection`  
**Workbench view:** `LabWorkbenchView.patients` (UI always patients; `orders` residual in controller)

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `collection` (Pending) | `pending` | `collection`, `sample`, `awaiting-results`, `awaiting_results`, `awaitingresults`, `pending-verification`, `pending_verification`, `pendingverification`, `processing`, `in-process`, `verification`, `results` | [01-collection.md](01-collection.md) |
| `critical` | `critical` | — | [02-critical.md](02-critical.md) |
| `completed` | `completed-today` | `verified`, `completed`, `completed_today`, `done` | [03-completed.md](03-completed.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [04-follow-ups.md](04-follow-ups.md) |
| `worklist` (All patients) | `worklist` | `all` | [05-worklist.md](05-worklist.md) |

Helpers: `_sectionToQueryValue` / `_sectionFromQuery` on `LabWorkspacePage` (enum in `lab_entities.dart`).

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/lab/presentation/pages/lab_workspace_page.dart`
- `frontend/lib/features/lab/presentation/lab_access.dart`
- `frontend/lib/features/lab/presentation/widgets/lab_scope_navigation.dart`
- `frontend/lib/features/lab/presentation/widgets/lab_workspace_print_helpers.dart`
- `frontend/lib/features/lab/domain/entities/lab_entities.dart`
- `frontend/lib/features/lab/presentation/controllers/lab_workspace_controller.dart`
- `frontend/lib/features/lab/presentation/pages/lab_result_entry_dialog.dart`
- `frontend/lib/features/lab/presentation/pages/lab_desk_settings_dialog.dart`
- `frontend/lib/features/lab/presentation/pages/lab_report_preview_settings_dialog.dart`
- `frontend/lib/features/lab/presentation/lab_desk_preferences.dart`
- `frontend/lib/features/lab/presentation/lab_report_preview_preferences.dart`
- `frontend/lib/features/lab/presentation/lab_status_display.dart`
- `frontend/test/features/lab/`
