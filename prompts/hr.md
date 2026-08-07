# Flatten HR Desk Tabs (No Nested Queues)

Refactor the HR workspace so every worklist lives on a **single primary `AppTabStrip`**—no nested queue switcher—while keeping staff, leave, shifts, payroll, and access behavior, permissions, and deep-links intact unless this prompt requires a change.

## Context

**Current behavior (screenshot + codebase; `/hr?section=shift-roster`)**

- **Primary strip (`HrDeskSection`):** Human resources (`staff`), Leave requests (`leave-requests`), Shifts (`shift-roster` / `shifts`), Payroll drafts (`payroll`), Manage users and roles (`access`). Gated by `hrAllowedSections` / per-tab atoms in `hr_access.dart`.
- **Nested strip (problem):** On Shifts only, `_HrWorkQueueSwitcherRow` + `HrQueueSwitcher` renders a second tab row for all five `workspaceQueues`: Leave requests, Swap requests, Roster drafts, Unassigned shifts, Payroll drafts. That duplicates Leave/Payroll primaries and lets users change queue without changing section.
- **Queue → section map today:** Leave/swap → Leave tab; roster/unassigned/overdue → Shifts; payroll → Payroll. Leave and Payroll bodies already omit the switcher and load a fixed queue; Swap is effectively reachable via the Shifts nested strip (or `?queue=`), not a dedicated primary.
- **Preserve:** Staff directory, work-item tables/dialogs/next-actions, schedule templates, access embed, billing inventories, RBAC/ABAC, soft-refresh, existing `?section=` / `?queue=` / `?id=` deep-links (remap destinations if IA changes).

**Intended behavior**

- One tab level only. No `HrQueueSwitcher` (or equivalent second strip) in the HR workspace body.
- Prefer **fewest primaries**: keep the five `HrDeskSection`s; do **not** promote every `HrQueue` to its own primary.
- Consolidate related queues **inside** their owning primary via existing **Filters** (or equivalent non-tab facet)—not nested tabs:
  - **Leave requests:** leave + swap (default leave).
  - **Shifts:** roster drafts + unassigned (+ overdue when deep-linked); default roster drafts. Badge stays draft + unassigned + overdue.
  - **Payroll drafts:** payroll only (remove from any shift-local chrome).
- Staff and Access unchanged in role and chrome.

**Definitions**

- *Primary tab:* One `AppTabItem` in the HR `AppTabStrip` (`HrDeskSection`).
- *Nested tabs:* Any second tab/segment row that switches `HrQueue` (e.g. `HrQueueSwitcher`). Forbidden on the desk.
- *Queue facet:* Filter (or similar progressive control) that selects leave vs swap, or roster vs unassigned vs overdue, without a second tab strip.

## Requirements

1. **Remove nested queue chrome:** Delete workspace use of `HrQueueSwitcher` / `_HrWorkQueueSwitcherRow` under Shifts (and any leftover panel). Do not reintroduce a second tab strip.
2. **Keep five primaries; assign entities:** Human resources = staff; Leave = leave+swap via facet; Shifts = roster/unassigned/overdue via facet; Payroll = payroll drafts; Access = manage users/roles. Do not add Swap/Unassigned/Roster as new primaries.
3. **Default loads & facets:** Selecting Leave loads leave; Shifts loads roster drafts; Payroll loads payroll. Facets switch related queues and update list/URL. Overdue may appear only when selected/deep-linked (same as today’s special case), not as a permanent nested tab.
4. **Deep-links & Home tally:** `?section=` / `?tab=` / `?queue=` open the owning primary with the matching queue applied. Remap any Home/dashboard routes that assumed nested Shifts→leave/payroll. Preserve staff `?id=` behavior.
5. **Counts & chrome:** Tab badges and search trailing actions stay section-scoped (Leave ≈ leave count; consider whether swap should contribute—document choice in code; Shifts = draft+unassigned+overdue; Payroll = draft runs). Unauthorized tabs/actions absent—no disabled stubs.
6. **States & sync:** Loading / empty / error / success / validation unchanged; soft-refresh after mutations; theme tokens; light/dark; responsive without overflow or duplicate controls.
7. **Tests:** Update workspace, queue-switcher, shifts/leave/payroll permission & billing section tests for the flat IA; prove nested switcher absent; authorized tabs/actions remain; deep-link queue→section cases green.

## Constraints

- Reuse `HrWorkspacePage`, controller, work-item table, filters, dialogs, `HrDeskSection` / `HrQueue`, and shared list/search kit. No parallel HR shell.
- Follow `.cursor/mandatories.mdc`, `.cursor/access/permissions.mdc`, `prompts/.cursor/prompt.mdc`, `frontend/.cursor/layouts.mdc`.
- Out of scope: new HR entities, payroll math, access RBAC redesign, Reports Overview, production seeding.
- Optional: retire or narrow `HrQueueSwitcher` to non-workspace surfaces only if still referenced; prefer delete if unused.

## Acceptance Criteria

| # | Criterion | Maps to |
| --- | --- | --- |
| A1 | HR desk shows only the primary `AppTabStrip`; no nested leave/swap/roster/unassigned/payroll row under Shifts. | R1 |
| A2 | Five primaries remain; leave+swap owned by Leave; shift queues by Shifts; payroll by Payroll; staff/access unchanged. | R2 |
| A3 | Tab select loads the default queue; facets switch related queues without a second tab strip. | R3 |
| A4 | `?section=` / `?queue=` (and Home links) land on the owning primary with the correct queue; staff deep-links preserved. | R4 |
| A5 | Badges/actions stay correct and permission-gated; unauthorized chrome absent. | R5 |
| A6 | Load/empty/error/success work; themes and viewports usable; lists refresh after mutations. | R6 |
| A7 | Updated HR workspace/section/permission tests pass; nested switcher assertions removed or inverted. | R7 |

## Relevant Files

- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart`
- `frontend/lib/features/hr/presentation/widgets/hr_queue_switcher.dart`
- `frontend/lib/features/hr/domain/entities/hr_entities.dart` (`HrDeskSection`, `HrQueue`, `HrWorkspaceQuery`)
- `frontend/lib/features/hr/presentation/hr_access.dart`, `controllers/hr_workspace_controller.dart`
- Home/metric routes that deep-link `/hr?section=` / `?queue=`
- Tests: `hr_workspace_page_test.dart`, `hr_queue_switcher_test.dart`, `hr_*_permissions_test.dart`, `hr_*_billing_sections_test.dart`

## Verification

- Unit/widget: flat strip only; Leave/Shifts facets; queue deep-links; permission absence.
- Manual: `/hr` → Shifts has no second tab row; Leave reaches swap via Filters; Payroll only via Payroll tab; Access/staff unchanged; light/dark + narrow width.
