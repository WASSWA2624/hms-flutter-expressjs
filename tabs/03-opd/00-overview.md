# OPD workspace UI inventory

Source: `tabs-lister/03-opd.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `OpdWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/opd` (`AppRoutes.opd`)  
**Page:** `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`  
**Access:** `frontend/lib/features/opd/presentation/opd_access.dart`  
**Sections enum:** `OpdWorkspaceSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `all` | _(omit / empty)_ | default | [01-all.md](01-all.md) |
| `arrivals` | `arrivals` | `appointments` | [02-arrivals.md](02-arrivals.md) |
| `queue` | `queue` | `desk-queue`, `desk_queue` | [03-queue.md](03-queue.md) |
| `triage` | `triage` | — | [04-triage.md](04-triage.md) |
| `active` | `active` | `active_flow`, `encounters`, `flows` | [05-active.md](05-active.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [06-follow-ups.md](06-follow-ups.md) |

Helpers: `_parseOpdSection` / `_opdSectionQueryValue` / `OpdWorkspaceQuery` in `opd_entities.dart` + workspace page.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/opd/presentation/pages/opd_workspace_page.dart`
- `frontend/lib/features/opd/presentation/opd_access.dart`
- `frontend/lib/features/opd/domain/entities/opd_entities.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_workspace_controller.dart`
- `frontend/lib/features/opd/presentation/controllers/opd_encounter_dialog_controller.dart`
- `frontend/lib/shared/opd_actions/` (Flow / Appointment / Queue hubs, encounter, print summary)
- `frontend/lib/shared/follow_up/follow_up_worklist_panel.dart`
- `frontend/test/features/opd/`
