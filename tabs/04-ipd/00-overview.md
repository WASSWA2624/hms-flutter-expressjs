# IPD workspace UI inventory

Source: `tabs-lister/04-ipd.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `IpdWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/ipd` (`AppRoutes.ipd`)  
**Page:** `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`  
**Access:** `frontend/lib/features/ipd/presentation/ipd_access.dart`  
**Sections enum:** `IpdWorkspaceSection`  
**Detail panels:** `IpdDetailPanel` — `beds`, `nursing`, `medication`, `discharge`, `transfer`, `rounds`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `admissionQueue` | `admission-queue` | `admission_queue`, `admissionqueue`, `queue` | [01-admission-queue.md](01-admission-queue.md) |
| `activePatients` | `active` | `active-patients`, `active_patients`, `activepatients` | [02-active-patients.md](02-active-patients.md) |
| `transferPending` | `transfers` | `transfer-pending`, `transfer_pending`, `transferpending` | [03-transfers.md](03-transfers.md) |
| `dischargePlanned` | `discharge` | `discharge-planned`, `discharge_planned`, `dischargeplanned` | [04-discharge.md](04-discharge.md) |
| `bedBoard` | `bed-board` | `bed_board`, `bedboard`, `beds` | [05-bed-board.md](05-bed-board.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups` | [06-follow-ups.md](06-follow-ups.md) |

Helpers: `IpdWorkspaceSectionX.fromQueryParam` / `_sectionToQueryValue` / `IpdAdmissionQuery` / `IpdDetailPanelX` in `ipd_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/ipd/presentation/pages/ipd_workspace_page.dart`
- `frontend/lib/features/ipd/presentation/ipd_access.dart`
- `frontend/lib/features/ipd/domain/entities/ipd_entities.dart`
- `frontend/lib/features/ipd/presentation/controllers/ipd_workspace_controller.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_bed_board_panel.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_board_next_action.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_start_admission_dialog.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_transfer_request_dialog.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_transfer_update_dialog.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_nursing_note_dialog.dart`
- `frontend/lib/features/ipd/presentation/widgets/ipd_clinical_order_actions.dart`
- `frontend/lib/shared/ipd_actions/`
- `frontend/lib/shared/follow_up/follow_up_worklist_panel.dart`
- `frontend/lib/features/discharge/presentation/widgets/show_discharge_planning_dialog.dart`
- `frontend/test/features/ipd/`
