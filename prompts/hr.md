# Flatten HR Desk Tabs (Entity-Per-Primary)

Refactor the HR workspace so every worklist is a **primary `AppTabStrip` tab**—no nested queue switcher—while preserving staff, leave, swap, roster, unassigned, payroll, and access behavior, permissions, and deep-links unless this prompt requires a change.

## Context

**Current behavior (feedback after first flatten)**

- Nested Shifts queue strip removed.
- Four visible primaries (Human resources, Leave, Shifts, Payroll) felt **insufficient**—swap / roster / unassigned were buried in Filters.
- Manage users and roles remains a fifth/seventh primary when entitled.

**Intended behavior**

- One tab level only. No nested queue strip.
- **Entity-per-primary** flat strip (order):
  1. Human resources (`staff`) — staff directory  
  2. Leave requests (`leave-requests`)  
  3. Swap requests (`swap-requests`)  
  4. Roster drafts (`shift-roster` / `shifts` aliases)  
  5. Unassigned shifts (`unassigned-shifts`; overdue deep-links here)  
  6. Payroll drafts (`payroll`)  
  7. Manage users and roles (`access`)  
- Each worklist tab loads exactly one queue. Desk Filters stay **status-only** (no queue facet). Dialog “Work queues” may still offer all queues in Filters.
- Trailing actions: Add staff / Request leave / Schedule templates (Roster drafts only).

**Definitions**

- *Primary tab:* One `AppTabItem` in the HR `AppTabStrip` (`HrDeskSection`).
- *Nested tabs:* Any second tab row that switches `HrQueue`. Forbidden.

## Requirements

1. **No nested queue chrome** on the desk or dialog strip.
2. **Seven primaries** as listed; do not re-merge swap/unassigned into Leave/Shifts via Filters.
3. **Defaults & deep-links:** Tab select loads that section’s queue; `?queue=` wins over conflicting `?section=`; URL keeps `section` + `queue`. Home metric routes include both.
4. **Counts:** Leave / swap / roster / unassigned(+overdue) / payroll badges are section-scoped. Unauthorized tabs absent.
5. **States & sync:** Load/empty/error/success; soft-refresh; theme tokens; responsive (overflow “More” OK on narrow).
6. **Tests:** Entity map, deep-links, permission/billing suites; nested switcher absent; authorized chrome remains.

## Constraints

- Reuse `HrWorkspacePage`, controller, work-item table, dialogs, shared kit. No parallel HR shell.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Out of scope: new entities, payroll math, access RBAC redesign, Reports, production seeding.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | Strip shows Leave, Swap, Roster drafts, Unassigned, Payroll (+ staff/access when entitled); no nested queue row. | R1, R2 |
| A2 | Each worklist tab loads its own queue; Filters do not switch desk queues. | R2, R3 |
| A3 | `?section=` / `?queue=` and Home links land on the owning primary. | R3 |
| A4 | Badges/actions permission-gated; unauthorized chrome absent. | R4 |
| A5 | Themes/viewports usable; lists refresh after mutations. | R5 |
| A6 | Updated HR tests pass. | R6 |

## Relevant Files

- `frontend/lib/features/hr/domain/entities/hr_entities.dart`
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart`
- `frontend/lib/features/hr/presentation/hr_access.dart`
- Home metric routes under `frontend/lib/features/home/`
- Tests under `frontend/test/features/hr/`

## Verification

- Unit/widget: seven-section map; queue→section; no nested strip.
- Manual: `/hr` shows Swap + Roster drafts + Unassigned as primaries; Payroll unchanged; light/dark + narrow overflow.
