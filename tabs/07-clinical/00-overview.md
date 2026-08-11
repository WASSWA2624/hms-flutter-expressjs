# Clinical workspace UI inventory

Source: `tabs-lister/07-clinical.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `ClinicalWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/clinical` (`AppRoutes.clinical`)  
**Page:** `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`  
**Access:** `frontend/lib/features/clinical/presentation/clinical_access.dart`  
**Sections enum:** `ClinicalWorkspaceSection` (`all` = Pending)

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `all` (Pending) | _(omit / empty)_ | `pending`, `all`, legacy `waiting-review` / `in-consultation` variants | [01-pending.md](01-pending.md) |
| `assignedToMe` | `assigned-to-me` | `assigned_to_me`, `assignedtome`, `mine`, `assigned` | [02-assigned-to-me.md](02-assigned-to-me.md) |
| `urgent` | `urgent` | | [03-urgent.md](03-urgent.md) |
| `resultsReady` | `results-ready` | `results_ready`, `resultsready`, `results` | [04-results-ready.md](04-results-ready.md) |
| `completed` | `completed` | `completed-today`, `completed_today`, `closed`, `done` | [05-completed.md](05-completed.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [06-follow-ups.md](06-follow-ups.md) |

Helpers: `_clinicalSectionQueryValue` / `_parseClinicalSection` (page-local) + `ClinicalWorkspaceQuery.fromUri`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/clinical/presentation/pages/clinical_workspace_page.dart`
- `frontend/lib/features/clinical/presentation/clinical_access.dart`
- `frontend/lib/features/clinical/presentation/controllers/clinical_workspace_controller.dart`
- `frontend/lib/features/clinical/presentation/widgets/clinical_encounter_detail_panels.dart`
- Shared clinical actions under `frontend/lib/shared/` / clinical feature dialogs Clinical opens
- `frontend/test/features/clinical/`
