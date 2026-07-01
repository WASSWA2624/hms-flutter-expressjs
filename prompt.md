# HR Workspace — More Actions Menu Information Architecture

## Objective

Reorganize the **Human resources** workspace toolbar overflow menu (`More actions` ⋮) so HR administrators can **quickly find the right workflow** on first visit. Group related items into labeled sections, clarify overlapping entries (work queues vs. notifications), and separate **HR-specific** actions from **global workspace** actions — without changing underlying mutation handlers.

**Entry point:** `/hr` → toolbar **More actions** overflow (screenshot: flat list of Work queues, Manage users and roles, Schedule templates, HR activity, Refresh, Request maintenance, Report equipment fault, Notifications).

**Parent context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) §Phase 1 Toolbar; companion [prompt2.md](./prompt2.md) (dialog resize) should land first if not already done.

---

## Problem Statement (from current UI)

On the HR staff directory screen, the overflow menu presents a **single undifferentiated list** of eight items spanning unrelated domains:

| Item | Domain | Issue |
|------|--------|-------|
| Work queues | HR scheduling / approvals | Overlaps with **Notifications** submenu (same queue shortcuts) |
| Manage users and roles | HR ↔ Access Admin | Buried mid-list; high-frequency for new HR admins |
| Schedule templates | HR roster setup | Label implies full management; dialog is create-focused today |
| HR activity | HR audit | No visual grouping with other monitoring items |
| Refresh | Workspace utility | Mixed with HR workflows |
| Request maintenance | Housekeeping module | Non-HR; appears alongside staffing actions |
| Report equipment fault | Biomedical module | Non-HR; same confusion |
| Notifications | HR summary badges | Submenu with leave/roster/shift/payroll counts; relationship to **Work queues** unclear |

A first-time HR user cannot tell **where staffing ends and facilities begin**, or whether **Work queues** and **Notifications** are different features.

---

## Current Implementation

| Area | Location |
|------|----------|
| HR toolbar secondary actions | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — `appWorkspaceToolbarWithLabels` `secondary` list |
| Summary notification definitions | Same file — `_summaryNotifications` (leave, roster drafts, unassigned shifts, payroll drafts) |
| Shared toolbar + overflow renderer | `frontend/lib/shared/layout/app_workspace_toolbar.dart` — `_ToolbarOverflowMenu`, `_ToolbarNotificationsSubmenu` |
| Overflow action → menu entry resolver | `frontend/lib/shared/layout/app_toolbar_overflow_resolver.dart` |
| Toolbar widget tests | `frontend/test/shared/layout/app_workspace_toolbar_test.dart` |
| Strings | `frontend/lib/l10n/app_en.arb` |

**Toolbar order today (secondary):** Add staff → Work queues → Manage users and roles → Schedule templates → HR activity.

**Overflow composition:** Remaining secondary actions + global actions (Refresh, Request maintenance, Report equipment fault) + Notifications submenu. Default `maxVisibleScreenActions: 3` keeps the first three secondary buttons inline on md+; the rest collapse into overflow.

---

## Target Information Architecture

Follow patterns common in workforce / hospital admin systems (Workday, BambooHR, UKG): **group by job-to-be-done**, **primary CTA stays visible**, **alerts are scannable**, **utilities last**.

### Inline toolbar (md+, unchanged intent)

Keep **Add staff** as the primary labeled action. Promote **Work queues** inline when space allows (it is the main operational entry). Other groups live in overflow.

### Overflow menu — grouped sections

Render **section headers** (non-interactive labels) and **dividers** between groups inside `_ToolbarOverflowMenu`. Proposed structure:

#### 1. Staff & access
| Item | Notes |
|------|-------|
| Manage users and roles | Opens `showHrAccessWorkspaceDialog`; keep permission-gated |
| *(optional future)* Open Users/Roles admin | Only if deep-link already exists; do not add net-new routing in this task |

#### 2. Scheduling & roster
| Item | Notes |
|------|-------|
| Work queues | Opens full work-queue dialog (`showHrWorkQueueDialog`) |
| Schedule templates | Opens `showHrManageScheduleTemplatesDialog`; rename label to **Create schedule template** if manage list is not yet built (per parent prompt) |

#### 3. Approvals & alerts
| Item | Notes |
|------|-------|
| Notifications | Existing submenu — leave requests, roster drafts, unassigned shifts, payroll drafts with count badges |
| *(do not duplicate)* | Notification child items must **not** also appear as top-level overflow rows |

**Clarify the distinction in copy (tooltips or section subtitle):**
- **Work queues** = browse and act on all queue types in one dialog.
- **Notifications** = jump directly to queues that need attention (badge-driven shortcuts).

#### 4. Activity & audit
| Item | Notes |
|------|-------|
| HR activity | Opens activity timeline dialog (`_showActivityDialog`) |

#### 5. Workspace
| Item | Notes |
|------|-------|
| Refresh | Existing `onRefresh` handler |

#### 6. Facilities *(show only when module + permission allow)*
| Item | Notes |
|------|-------|
| Request maintenance | Existing global action; already gated in resolver |
| Report equipment fault | Existing global action; already gated in resolver |

If both facilities items are hidden, **omit the entire Facilities section** (no empty header).

---

## Implementation Requirements

### 1. Sectioned overflow menu (shared component)

Extend the toolbar overflow system to support **ordered groups** instead of a flat `List<Widget>`:

- Add an `AppToolbarOverflowSection` model: `{ String? headerLabel, List<Widget> actions }`.
- Update `_ToolbarOverflowMenu` to render:
  - Section header — `MenuLabel` or styled `Text` matching design tokens (`onSurfaceVariant`, `labelSmall`).
  - `Divider` between sections (not before first / after last).
  - Existing `MenuItemButton` rows per action.
  - Notifications submenu remains the **last item in Approvals & alerts** (or immediately after that section’s header).
- Preserve existing behavior: permission gating, disabled states, attention badge on ⋮ trigger, click-to-open notifications submenu (fix from parent prompt if still broken).

**Prefer a shared abstraction** so other modules can adopt grouped overflow later; HR is the first consumer.

### 2. HR workspace toolbar wiring

In `hr_workspace_page.dart`, replace the flat `secondary` list passed to `appWorkspaceToolbarWithLabels` with an explicit **section map** (or ordered sections) matching the IA above.

- Reorder overflow entries to match target groups even when actions collapse from inline → overflow.
- Set `maxVisibleScreenActions` deliberately (recommend `2`: Add staff + Work queues) so high-frequency paths stay visible on desktop.
- Pass global actions (Refresh, maintenance, fault) in a **Workspace** / **Facilities** section rather than appending them blindly at the end of screen actions.

### 3. Copy and accessibility

- Add l10n keys for section headers, e.g.:
  - `workspaceToolbarSectionStaffAccess`
  - `workspaceToolbarSectionScheduling`
  - `workspaceToolbarSectionApprovals`
  - `workspaceToolbarSectionActivity`
  - `workspaceToolbarSectionWorkspace`
  - `workspaceToolbarSectionFacilities`
- Add short tooltips where Work queues vs. Notifications could still confuse.
- Section headers are **presentational only** — exclude from keyboard action count; menu items retain `semanticLabel`s.

### 4. Deduplication rules

- **No duplicate queue shortcuts** at the top level and inside Notifications.
- **Do not remove** Work queues or Notifications — clarify roles via grouping and copy.
- **Do not merge** Manage users and roles into staff row actions; it is a workspace-level admin entry.

### 5. Tests

- Update `app_workspace_toolbar_test.dart`:
  - Section headers render in expected order.
  - Dividers appear between sections.
  - Facilities section hidden when both global actions are disallowed.
  - Notifications submenu still shows aggregate badge and child counts.
- Add HR-focused widget test (optional, lightweight): pump `HrWorkspacePage` at narrow width → open overflow → assert section headers and key action labels.

### 6. Quality gate

- `flutter analyze` clean for touched files.
- `flutter test` for `app_workspace_toolbar_test.dart` and any new HR toolbar test.

---

## Global Standards

- Hospital workflow language — no raw enum names in labels.
- Reuse `frontend/lib/shared/*` (`AppButton`, `AppMenuItemLabel`, `AppMenuCountBadge`, theme spacing/radius).
- All new strings in `frontend/lib/l10n/app_en.arb`.
- **No new routes** — all actions keep existing dialog handlers.
- **No handler rewiring** — layout/IA/copy only unless a label rename is required.
- Permission gates unchanged (`hrRead`, `hrWrite`, module entitlements for global actions).

---

## Acceptance Criteria

- [ ] Overflow menu shows **labeled sections** in the order defined above.
- [ ] HR-specific actions are grouped separately from **Workspace** and **Facilities** utilities.
- [ ] **Add staff** and **Work queues** remain inline on md+ viewports; overflow contains the rest.
- [ ] **Notifications** submenu works via click (stable submenu); badge reflects attention total.
- [ ] Work queues vs. Notifications distinction is clear from section placement + tooltip/copy.
- [ ] Facilities section omitted when user lacks both maintenance and fault-report access.
- [ ] No duplicate menu entries; all existing actions still reachable.
- [ ] Widget tests cover section rendering and notifications behavior.
- [ ] Manual QA: `.\tool\run_web_5201.ps1` → `/hr` → resize to trigger overflow → verify grouping at 1280px and 900px widths.

---

## Out of Scope

- Full schedule-template list/edit/delete CRUD.
- Changing work-queue dialog internals or queue mutation logic.
- Staff detail action grouping (separate item in parent prompt).
- Backend API changes.
- Replacing overflow with a permanent sidebar or command palette.
