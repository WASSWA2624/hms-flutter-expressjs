# Gate Cancel and Appointments Against Active Encounters

Keep Reception Appointments for pre-encounter bookings, and allow **Cancel appointment** only with no linked active encounter. Follow `prompts/.cursor/prompt.mdc`.

## Context

Appointments still lists open-encounter patients also on Desk queue / Active visits. Cancel stays available after the encounter starts. Schedule warns on active encounters but offers no continue/update path.

**Active encounter:** non-terminal OPD/Emergency flow via `findActiveOpdFlowForAppointment`.

## Requirements

1. On Appointments, list only non-terminal appointments with no linked active encounter. Keep those visits on Desk queue and Active visits; refresh search, filters, and counts.
2. Hide **Cancel appointment** when a linked active encounter exists or the appointment is terminal; keep it for eligible bookings when authorized.
3. When scheduling finds an active encounter, block create and offer authorized **Continue encounter** plus edit/update via encounter and reschedule paths. Keep the warning.
4. After cancel or edit success, synchronize Appointments, Desk queue, Active visits, search, filters, and counts.
5. Preserve loading, empty, error, success, validation, busy, and permission states; omit unauthorized UI.

## Constraints

- Reuse eligibility, cancel/reschedule/encounter dialogs, authorization, localization, and design-system components.
- Do not invent cancel-encounter rules or alter Desk queue / Active visits beyond Appointments filtering.

## Acceptance Criteria

- R1: Appointments excludes active-encounter rows; other tabs and counts stay correct.
- R2: Cancel hidden once an encounter is linked; still works for eligible bookings.
- R3: Schedule blocks create and surfaces continue/edit for active encounters.
- R4–R5: Success refreshes lists; states clear; unauthorized UI absent.
- Update eligibility, cancel, schedule, and reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/shared/opd_actions/`
- `frontend/test/features/reception/`
