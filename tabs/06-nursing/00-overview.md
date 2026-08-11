# Nursing workspace UI inventory

Source: `tabs-lister/06-nursing.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `NursingWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/nursing` (`AppRoutes.nursing`)  
**Page:** `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`  
**Access:** `frontend/lib/features/nursing/presentation/nursing_access.dart`  
**Scopes enum:** `NursingQueueScope`  
**Detail panels:** `NursingDetailPanel` (`checklist`, `vitals`, `medication`, `handover`, `discharge`)

## Desk tabs (order — `nursingTabStripOrder`)

| Enum | Query `scope` | Aliases | File |
| --- | --- | --- | --- |
| `all` | `all` (default) | `''` | [01-all.md](01-all.md) |
| `assignedWard` | `assigned-ward` | `assigned_ward`, `ward` | [02-assigned-ward.md](02-assigned-ward.md) |
| `urgent` | `urgent` | `critical` | [03-urgent.md](03-urgent.md) |
| `medicationDue` | `medication-due` | `medication_due`, `medication` | [04-medication-due.md](04-medication-due.md) |
| `handoverPending` | `handover-pending` | `handover_pending`, `handover` | [05-handover-pending.md](05-handover-pending.md) |
| `transferPending` | `transfer-pending` | `transfer_pending`, `transfer` | [06-transfer-pending.md](06-transfer-pending.md) |
| `dischargePending` | `discharge-pending` | `discharge_pending`, `discharge` | [07-discharge-pending.md](07-discharge-pending.md) |

Helpers: `nursingScopeToQueryValue` / `nursingScopeFromQueryValue` in `nursing_scope_navigation.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/nursing/presentation/pages/nursing_workspace_page.dart`
- `frontend/lib/features/nursing/presentation/nursing_access.dart`
- `frontend/lib/features/nursing/domain/entities/nursing_entities.dart`
- `frontend/lib/features/nursing/presentation/controllers/nursing_workspace_controller.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_panel.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_columns.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_worklist_filters.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_patient_detail_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_medication_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_handover_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_discharge_clearance_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_print_summary_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_shift_context_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_vitals_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_transfer_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_escalation_dialog.dart`
- `frontend/lib/features/nursing/presentation/widgets/nursing_note_dialog.dart`
- `frontend/test/features/nursing/`
