# Reception: Front-Desk Access, Visitor Booking, and Staff Reports

Confine receptionist-focused users to front-desk work (deny OPD/Emergency **workspaces**), extend appointment booking to visitors and any staff with availability checks, grant default Reports access to all staff, and remove the receptionist home profile card.

## Context

**Current behavior**

- `receptionistFocusedShellRoutes` includes `/opd` and `/emergency`; default packs grant `opd:read` / `emergency:*`.
- Home shortcuts include OPD/Emergency; `emergency_cases_today` opens Emergency.
- Book appointment is patient-centric (`PatientAppointmentQuickDialog` / OPD encounter) and provider pickers lean clinical; visitor↔any-staff meetings are not a first-class flow.
- Provider schedule hints exist for clinical booking (`OpdProviderSchedule`); staff availability/roster APIs exist under HR/availability-slots but are not the Reception meeting gate.
- `RECEPTIONIST` lacks `reports:read`; focused shells omit `/reports`. Other staff packs often include it, but role lists / focused shells are incomplete.
- Receptionist home can surface a **profile** shortcut/card via `expandHomeProfileForPermissions` (cross-profile `profile` / `profile_status` merge).

**Intended behavior**

- No OPD/Emergency workspace access for receptionist-focused users; keep OPD/emergency **desk info** and front-desk actions inside `/reception`.
- Receptionists book appointments for **visitors** (non-patients) with **any facility staff** (admins, clinical, non-clinical), after confirming the host’s schedule/availability.
- Existing patient clinical booking remains; visitor/staff meetings must not force a patient record or clinical encounter.
- All **staff** roles get `reports:read` by default and can open Reports when entitled; focused shells must not hide Reports when the grant is present.
- Receptionist dashboard must not show the profile card/shortcut.

**Definitions**

- *Receptionist-focused user*: `isReceptionistFocusedShellUser`.
- *OPD/Emergency screen*: `/opd`, `/emergency` (incl. deep links).
- *Visitor appointment*: scheduled meeting whose subject is not a patient (guest/visitor identity), hosted by a staff user.
- *Staff host*: any active facility staff user eligible for meetings (not limited to clinical providers).
- *Availability check*: reject or block booking when the host has a conflicting appointment, blocked slot, or is outside declared availability/roster for the requested interval (backend authoritative).

## Requirements

1. Remove `AppRoutes.opd` and `AppRoutes.emergency` from `receptionistFocusedShellRoutes`; route guards must deny those destinations for receptionist-focused users.
2. Hide shell nav, home shortcuts, metrics, and workflow actions that navigate to `/opd` or `/emergency` for receptionist-focused users (absence, not disabled stubs). Retarget `emergency_cases_today` (and similar) to Reception (prefer High priority / desk queue).
3. Preserve Reception tabs and front-desk hubs that show visit/queue/emergency-priority data; keep in-Reception OPD dialogs for allowed desk stages; strip only controls whose sole purpose is opening OPD/Emergency workspaces.
4. Align receptionist packs: drop workspace-only `opd:read` / emergency entry-write as needed; keep Reception rights (`patient:*`, `reception:read`, `last_office:*`, communications/profile). Document nested High-priority emergency chrome (`emergency:read` without shell access vs Reception read gates). Dual-role non-focused users keep OPD/Emergency when otherwise authorized.
5. Extend Book appointment / Schedule so receptionists can create **visitor appointments** with **any staff host** (e.g. admin meetings), without requiring a patient registry record or clinical encounter pathway.
6. Before confirming a booking (and on reschedule), validate the host’s **schedule/availability** and conflicts; surface loading, validation, and error states; succeed only when the backend accepts the slot. Reuse existing schedule/availability contracts where possible.
7. Keep visitor meetings visible on Reception Appointments (and related desk lists) with clear non-patient labeling; do not auto-create OPD clinical visits for visitor/staff meetings.
8. Add `reports:read` to default packs for **all staff** roles that lack it (including `RECEPTIONIST`); include `AppRoutes.reports` in receptionist (and other) focused shells so entitled staff can open Reports. Keep authorization permission-based—do not open Reports without the grant.
9. On the receptionist home profile, omit the profile status card and profile shortcut (suppress cross-profile merge of `profile` / `profile_status` / `my_profile_status` for receptionist). Profile remains reachable from Settings/shell where already allowed—not as a dashboard card.
10. Update shell, home, reception, and booking tests; cover unauthorized UI absence and authorized Reception/Reports/visitor-booking presence. Reuse design-system patterns; cover permission/loading/empty/error/success/validation/feedback where UI changes.

## Constraints

- Reuse `canAccessShellRoute`, `AppAccessPolicy`, Reception atoms, home filters, and existing appointment/availability APIs—no parallel auth stacks.
- Backend RBAC/ABAC remains authoritative; UI hide alone is insufficient.
- No unrelated OPD/Emergency/HR refactors beyond access, booking, reports entitlement, and dashboard chrome.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Focused receptionist: no `/opd` or `/emergency` via shell/deep link; `/reception` allowed. | R1–R2 |
| A2 | No OPD/Emergency nav/shortcuts/actions; emergency KPI opens Reception or is omitted. | R2 |
| A3 | Reception still shows desk OPD/queue/emergency-relevant data and allowed front-desk actions. | R3–R4 |
| A4 | Receptionist can book a visitor↔staff meeting without a patient; clinical patient booking still works. | R5, R7 |
| A5 | Booking/reschedule blocked with validation feedback when host unavailable or conflicted; success when free. | R6 |
| A6 | All staff default packs include `reports:read`; focused receptionist (and peers) can open `/reports` with that grant. | R8 |
| A7 | Receptionist home has no profile card/shortcut; Settings profile access unchanged if previously allowed. | R9 |
| A8 | Tests prove denials/absences and authorized flows; dual-role clinical users retain OPD/Emergency. | R4, R10 |

## Relevant Files

- `frontend/lib/app/router/app_routes.dart`, `shell_route_access.dart`
- `frontend/lib/core/permissions/access_policy.dart`, `route_access_catalog.dart`
- `frontend/lib/features/reception/presentation/reception_access.dart`, workspace/appointment widgets
- `frontend/lib/shared/opd_actions/patient_appointment_quick_dialog.dart`, `opd_provider_options.dart`, encounter/reschedule dialogs
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart`, `home_metric_routes.dart`, `home_dashboard_actions.dart`
- `backend/src/config/permissions.js`; appointment + availability/roster modules as reused by booking
- Tests: `shell_route_access_test.dart`, reception/home permission & metric tests, appointment dialog tests

## Verification

- Flutter tests: shell access, reception access, home shortcuts/metrics, reports entitlement, visitor booking + availability validation.
- Manual `RECEPTIONIST`: no OPD/Emergency; book visitor with admin when free / blocked when busy; Reports opens; no home profile card.
- Manual dual-role doctor: OPD/Emergency still open. Check light/dark and narrow viewports.
