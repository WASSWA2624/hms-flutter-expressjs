# Reception workspace UI inventory

Source: `01-reception.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `ReceptionWorkspacePage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

**Workspace:** `/reception` (`AppRoutes.reception`)  
**Page:** `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`  
**Access:** `frontend/lib/features/reception/presentation/reception_access.dart`  
**Sections enum:** `ReceptionDeskSection`

## Desk tabs (order)

| Enum | Query `section` | Aliases | File |
| --- | --- | --- | --- |
| `appointments` | `appointments` | `meetings` | [01-appointments.md](01-appointments.md) |
| `queue` | `desk-queue` | `queue`, `desk_queue` | [02-desk-queue.md](02-desk-queue.md) |
| `highPriority` | `high-priority` | `high_priority`, `priority` | [03-high-priority.md](03-high-priority.md) |
| `activeVisits` | `active` | `active-visits`, `active_visits`, `visits`, `in-progress`, `turnaround_pressure` | [04-active-visits.md](04-active-visits.md) |
| `followUps` | `follow-ups` | `follow_ups`, `followups`, `follow-up`, `no_show_pressure` | [05-follow-ups.md](05-follow-ups.md) |
| `paymentGate` | `payment-gate` | `payment`, `pending_balance_amount`, `pending-payments` | [06-payment-gate.md](06-payment-gate.md) |

Helpers: `receptionDeskSectionToQueryValue` / `receptionDeskSectionFromQuery` in `reception_entities.dart`.

## Shared / cross-tab chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`
- `frontend/lib/features/reception/domain/entities/reception_entities.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_appointment_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_queue_actions_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_follow_up_detail_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_payment_gate_detail_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_visitor_appointment_dialog.dart`
- `frontend/lib/features/reception/presentation/widgets/reception_patient_actions.dart`
- `frontend/lib/features/reception/presentation/controllers/reception_payment_gate_controller.dart`
- `frontend/lib/features/reception/presentation/controllers/reception_follow_up_controller.dart`
- `frontend/lib/shared/opd_actions/` (reused hubs)
- `frontend/test/features/reception/`
