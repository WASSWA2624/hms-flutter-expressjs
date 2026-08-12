# Theater workspace UI inventory

Source: `tabs-lister/08-theater.md` · Code base date: 2026-08-12

## Context

Catalog of every visible / reachable UI atom on `TheaterWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/theater` (`AppRoutes.theater`)  
**Page:** `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`  
**Access:** `frontend/lib/features/theater/presentation/theater_access.dart`  
**Sections enum:** `TheaterSection`  
**Detail panels:** `TheaterDetailPanel` (`checklist`, `anesthesia`, `postop`, `resources`)

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `scheduled` | `scheduled` | — | [01-scheduled.md](01-scheduled.md) |
| `inTheater` | `in-theater` | `in_theater`, `intheater` | [02-in-theater.md](02-in-theater.md) |
| `recovery` | `recovery` | `post-op`, `post_op`, `pacu` | [03-recovery.md](03-recovery.md) |
| `all` | `all` (omitted from URL when active) | default when unknown | [04-all.md](04-all.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [05-follow-ups.md](05-follow-ups.md) |

Helpers: `TheaterSectionX.queryValue` / `TheaterSectionX.fromQuery` in `theater_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/theater/presentation/pages/theater_workspace_page.dart`
- `frontend/lib/features/theater/presentation/theater_access.dart`
- `frontend/lib/features/theater/domain/entities/theater_entities.dart`
- `frontend/lib/features/theater/presentation/controllers/theater_workspace_controller.dart`
- `frontend/lib/features/theater/presentation/widgets/theater_workspace_widgets.dart`
- `frontend/lib/features/theater/presentation/widgets/theater_schedule_case_form.dart`
- `frontend/lib/features/theater/presentation/theater_next_action.dart`
- `frontend/test/features/theater/`
