# Gate Cancel and Appointments Against Active Encounters

Keep Reception Appointments for pre-encounter bookings, and allow **Cancel appointment** only with no linked active encounter. Follow `prompts/.cursor/prompt.mdc`.

## Context

Appointments still lists open-encounter patients also on Desk queue / Active visits. Cancel stays available after the encounter starts. Schedule warns but offers no continue/update path.

**Active encounter:** non-terminal OPD/Emergency flow via `findActiveOpdFlowForAppointment`.

## Requirements

1. Filter Appointments to non-terminal rows with no linked active encounter; refresh search, filters, counts. Leave Desk queue and Active visits unchanged.
2. Hide **Cancel appointment** when a linked active encounter exists or the appointment is terminal; keep for eligible authorized bookings.
3. On schedule active-encounter hit: block create; offer authorized **Continue encounter** and edit/update via encounter and reschedule paths; keep warning.
4. After cancel or edit success, synchronize Appointments, Desk queue, Active visits, search, filters, counts.
5. Preserve loading, empty, error, success, validation, busy, and permission states; omit unauthorized UI.

## Constraints

- Reuse eligibility, cancel/reschedule/encounter dialogs, authorization, localization, and design-system.
- Do not invent cancel-encounter rules or change Desk queue / Active visits beyond Appointments filtering.

## Acceptance Criteria

- R1: Appointments excludes active-encounter rows; other tabs and counts correct.
- R2: Cancel hidden once an encounter is linked; works for eligible bookings.
- R3: Schedule blocks create and surfaces continue/edit for active encounters.
- R4-R5: Success refreshes lists; states clear; unauthorized UI absent.
- Update eligibility, cancel, schedule, reception tests; run Flutter analysis.

## Relevant Files

- `frontend/lib/shared/opd_actions/`
- `frontend/lib/features/reception/presentation/`
- `frontend/test/shared/opd_actions/`
- `frontend/test/features/reception/`
