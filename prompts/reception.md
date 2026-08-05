# Reception: Deny OPD and Emergency Workspace Access

Confine the `RECEPTIONIST` / receptionist-focused shell to front-desk work. Deny the OPD and Emergency **workspaces** while preserving OPD- and emergency-related **information and front-desk actions** already owned by Reception.

## Context

**Current behavior**

- `AppRoutes.receptionistFocusedShellRoutes` includes `/opd` and `/emergency`, so focused receptionists see and open those screens.
- Default receptionist packs grant `opd:read`, `emergency:read`, and `emergency:write` (frontend `AppAccessPolicy` + backend `permissions.js`).
- Home receptionist shortcuts include `opd` and `emergency`; the `emergency_cases_today` metric navigates to `AppRoutes.emergency`.
- Reception already surfaces relevant visit/queue/emergency context inside `/reception` (Appointments, Desk queue, High priority, Active visits, Follow-ups, Payment gate) without requiring the OPD or Emergency workspace pages.

**Intended behavior**

- Reception role users must not open the OPD or Emergency screens (nav, shortcuts, metrics, workflow “open in …” actions, or deep links).
- They must still see and act on relevant OPD / emergency desk information **inside Reception**.
- Existing Reception front-desk mutations (register, schedule, check-in, queue, assign provider, follow-ups, etc.) must remain unless they exclusively navigate to `/opd` or `/emergency`.

**Definitions**

- *Receptionist-focused user*: `AppAccessPolicy.isReceptionistFocusedShellUser` (canonical `RECEPTIONIST` or equivalent front-desk-only custom role).
- *OPD / Emergency screen*: workspace routes `AppRoutes.opd` (`/opd`) and `AppRoutes.emergency` (`/emergency`), including deep links and query panels.
- *Reception-surfaced info*: rows, badges, filters, detail hubs, and guidance already shown on `/reception` (including emergency indicators on High priority / Active visits).

## Requirements

1. Remove `AppRoutes.opd` and `AppRoutes.emergency` from `receptionistFocusedShellRoutes` so focused shell users cannot access those destinations via `canAccessShellRoute`.
2. Ensure route guards reject direct `/opd` and `/emergency` navigation for receptionist-focused users (forbidden / redirect), matching other unauthorized shell destinations.
3. Hide (do not render) shell nav items, home shortcuts, quick actions, metric cards, and workflow actions that navigate to `/opd` or `/emergency` for receptionist-focused users. Prefer absence over disabled “no access” chrome per prompt standards.
4. Retarget receptionist home metric `emergency_cases_today` (and any other receptionist KPI that currently opens Emergency or OPD) to the appropriate Reception section (prefer High priority / desk queue) with query params already supported by `ReceptionWorkspaceQuery`.
5. Preserve Reception workspace tabs, lists, badges, and front-desk hubs that display OPD visit / queue / emergency-priority data. Do not remove emergency indicators or visit stage guidance from Reception solely because OPD/Emergency workspaces are denied.
6. Keep shared OPD action dialogs usable **from Reception** for allowed front-desk stages; strip or gate only controls whose sole purpose is routing into the OPD or Emergency workspace.
7. Align default receptionist permission packs (frontend + backend) with screen denial: drop grants that exist only to unlock OPD/Emergency workspaces (`opd:read`, and emergency workspace write/entry as applicable). Retain rights required for Reception data and mutations (`patient:*`, `reception:read`, `last_office:*`, communications/profile). If High priority nested emergency chrome still needs a grant, either keep `emergency:read` **without** shell/route access, or retarget that chrome to existing Reception read gates—document the choice in code comments and tests.
8. Do not change access for multi-role users who are **not** receptionist-focused (e.g. receptionist + doctor/nurse); they must retain OPD/Emergency when their other roles/permissions allow it.
9. Update authorization and shell tests that currently assert receptionist access to OPD/Emergency so they expect denial; add coverage that Reception remains allowed and that unauthorized OPD/Emergency UI atoms are absent for receptionist-focused policies.
10. Cover permission, loading, empty, error, success, validation, and visible-feedback states only where UI changes; reuse existing Reception patterns—no new design system.

## Constraints

- Reuse `canAccessShellRoute`, `AppAccessPolicy`, `AccessRequirement`, Reception atom permissions, and home `isAllowed` / metric routing—do not invent parallel gates.
- Backend remains authoritative; UI hiding alone is insufficient if APIs uniquely serve OPD/Emergency workspace entry for this role.
- No unrelated refactors of OPD, Emergency, or Reception feature modules beyond access and navigation retargeting.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, and Reception access comments in `reception_access.dart`.
- Unauthorized controls must not render; forbidden feedback only for direct restricted deep links or backend denial.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Focused receptionist `canAccessShellRoute` is false for `AppRoutes.opd` and `AppRoutes.emergency`, true for `AppRoutes.reception`. | R1, R2 |
| A2 | Shell nav, home shortcuts, and receptionist metrics do not offer OPD/Emergency destinations; emergency KPI opens Reception (or is omitted if unauthorized). | R3, R4 |
| A3 | `/reception` still shows OPD/queue/emergency-relevant desk data and allowed front-desk actions for a receptionist with the default pack. | R5, R6 |
| A4 | Controls that only navigate to `/opd` or `/emergency` are absent for receptionist-focused users; dual-role clinical users still reach those screens when authorized. | R3, R6, R8 |
| A5 | Default receptionist packs no longer rely on OPD/Emergency workspace entry permissions unless explicitly retained for in-Reception nested read (documented + tested). | R7 |
| A6 | Unit/widget tests prove unauthorized OPD/Emergency UI absent and authorized Reception UI present; shell/route tests updated. | R9 |
| A7 | Changed surfaces remain responsive and themed; no new unauthorized disabled stubs. | R3, R10 |

## Relevant Files

- `frontend/lib/app/router/app_routes.dart` — `receptionistFocusedShellRoutes`, OPD/Emergency role lists
- `frontend/lib/app/router/shell_route_access.dart` — focused-shell gate
- `frontend/lib/core/permissions/access_policy.dart` — receptionist pack + `isReceptionistFocusedShellUser`
- `frontend/lib/core/permissions/route_access_catalog.dart` — `opdEntry` / `emergencyEntry`
- `frontend/lib/features/reception/presentation/reception_access.dart` — desk atoms; High priority nested emergency read
- `frontend/lib/features/home/domain/entities/home_dashboard_profiles.dart` — receptionist shortcuts / metrics
- `frontend/lib/features/home/presentation/widgets/home_dashboard_actions.dart` — shortcut library
- `frontend/lib/features/home/presentation/widgets/home_metric_routes.dart` — `emergency_cases_today` target
- `frontend/lib/shared/workflow_actions/workflow_action_registry.dart` — actions routing to OPD/Emergency
- `backend/src/config/permissions.js` — `[ROLES.RECEPTIONIST]` pack
- Tests: `frontend/test/app/router/shell_route_access_test.dart`, `frontend/test/features/reception/presentation/reception_access_test.dart`, home metric/shortcut tests, high-priority permissions tests

## Verification

- Run focused Flutter tests for shell route access, reception access, home metric routes, and high-priority / workflow action gates.
- Manually: sign in as `RECEPTIONIST` — confirm no OPD/Emergency nav or shortcuts; Reception tabs still show queue/visit/emergency-priority info; deep-link `/opd` and `/emergency` are blocked.
- Manually: dual-role doctor+receptionist (or doctor alone) still opens OPD/Emergency.
- Confirm light/dark and narrow viewport: no leftover disabled OPD/Emergency controls in receptionist chrome.
