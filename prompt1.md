# Task: HR Workspace UI/UX Polish — Toolbar, Dialogs, Staff Detail, and Work Queues

## Objective

Improve the **Human Resources** workspace at `/hr` so toolbar actions, work-queue navigation, notifications submenu, and staff-detail dialogs are clear, professional, and easy to use on desktop/web. This pass focuses on **UI structure, labeling, dialog behavior, and layout** — not re-wiring staff-action business logic (that is a follow-up phase).

**Companion context:** [prompts/24-hr-module-prompt.md](./prompts/24-hr-module-prompt.md) (module scope), [prompt2.md](./prompt2.md) (`AppDialog` resize/maximize fix).

---

## Current State

| Area | Location | Notes |
|------|----------|-------|
| HR workspace page | `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` | Staff directory, dialogs, work-queue panel, staff detail body |
| HR dialogs/widgets | `frontend/lib/features/hr/presentation/widgets/hr_enhanced_dialogs.dart` | Shift template, role assign, roster preview, etc. |
| Controller | `frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart` | Queue filters, staff selection, mutations |
| Shared dialog shell | `frontend/lib/shared/components/app_dialog.dart` | Resize, maximize, footer actions |
| Workspace toolbar | `frontend/lib/shared/layout/app_workspace_toolbar.dart` | Overflow menu, notifications submenu |
| Action sections | `frontend/lib/shared/actions/app_action_panel.dart` | `AppActionSection`, `AppPermissionActionList` |
| Info tiles | `frontend/lib/shared/components/app_info_tile.dart` | `AppInfoTileGrid` used in staff overview |
| Strings | `frontend/lib/l10n/app_en.arb` | All labels via l10n — no hardcoded text |

**Toolbar today (secondary actions):**

1. `hrShiftTemplateAction` → "Manage schedule templates" → opens **create-only** shift-template mutation dialog
2. `hrWorkQueuesTitle` → opens work-queues `AppDialog`
3. `hrActivityTitle` → opens HR activity timeline dialog

Overflow (⋮) menu also exposes Refresh, global maintenance actions, and a **Notifications** submenu with summary counts (total staff, leave requests, roster drafts, unassigned shifts, payroll drafts).

**Staff detail flow:** selecting a staff row calls `selectStaff`, then opens `_openSelectedStaffDialog` — an `AppDialog` (`maxWidth: 980`, `scrollable: true`) containing `_HrStaffDetailPanel` → `_HrStaffDetailBody` (overview `AppInfoTileGrid`, `AppActionSection`, record sections).

**Work-queue dialog:** `_HrWorkQueuePanel` uses `AppWorkspaceDetailPanel` with **icon-only** queue switcher buttons (leave, swap, roster drafts, unassigned shifts, payroll drafts) and an `AppListTable` bound to `state.workItems`.

---

## Problems Observed (from QA at `127.0.0.1:5201/hr`)

### Toolbar and navigation

1. **Misleading schedule-template action** — Button reads "Manage schedule templates" but only opens a **create template** form. Users expect list/manage or at minimum a create-oriented label.
2. **Work queues buried or unclear** — Work queues should be a **primary toolbar action** (visible label on large screens), not only reachable via overflow. Queue switcher inside the dialog uses unlabeled icons; purpose is unclear without hovering tooltips.
3. **Notifications submenu hard to use** — Hovering "Notifications" in the overflow menu opens a flyout, but moving the pointer to select an item often closes the submenu (`_ToolbarNotificationsSubmenu` hover-only open, no safe bridge between parent menu and child).
4. **Overflow menu noise** — Items like "Request maintenance" and "Report equipment fault" feel out of place in HR; acceptable if global, but must not crowd HR-specific actions.

### Staff directory table

5. **Truncated next-action column** — "Review profile" clips to "Review profi…" on typical widths.
6. **Noisy department column** — Shows `Department | DEP-XXXXXXXX` inline; department name alone is enough for scan; IDs belong in detail/copy affordances.
7. **Summary card overlap** — "Total staff" notification/summary can float over table content and obscure rows.

### Staff detail dialog

8. **Maximize/resize broken** — Fullscreen header control does not fill the viewport; manual resize is unreliable (see [prompt2.md](./prompt2.md)).
9. **Redundant Close button** — Footer `Close` duplicates header ✕ on staff detail, work queues, and activity dialogs.
10. **Overview layout weak** — `AppInfoTileGrid` reads as flat, uneven cards; linked user crams name + email + ID into one long string; empty fields show "Not available" without hierarchy.
11. **Staff actions poorly organized** — Ten permission-gated actions (assign department, assign position, record availability, request leave, assign shift, swap shift, compensation, run payroll, assign role, view module access) render as an unstructured grid without grouping or visual priority.
12. **Repeated titles** — "Staff detail" appears in dialog header and again inside `AppWorkspaceDetailPanel`.

### Work queues and activity

13. **Queue switcher not responsive** — Icon-only on desktop; should show **text labels on large breakpoints** (md+), icons only on compact.
14. **Queue content must stay in sync** — Clicking a queue tab must call `controller.applyQueue`, refresh `state.workItems`, update description/subtitle, highlight active queue, and show correct empty/loaded table — end-to-end from `GET /hr/work-items?queue=`.
15. **HR activity purpose unclear** — Timeline shows sparse shift/roster events without actor, deep link, or filter. Acceptable to keep read-only, but needs a clear description or light enhancement so users understand it is an audit-style feed.

---

## Requirements

### 1. Toolbar actions — labels, order, and honesty

- On **md+ breakpoints**, show labeled secondary toolbar buttons per `AppActionLabelScope` / `appWorkspaceToolbarWithLabels` conventions.
- **Toolbar order (left → right among HR actions):** Work queues → Create schedule template → HR activity (adjust `maxVisibleScreenActions` so Work queues stays inline on typical desktop widths).
- **Rename schedule-template action** to reflect actual behavior:
  - **Phase 1 (this task):** Change `hrShiftTemplateAction` to **"Create schedule template"** (or equivalent). Keep existing create form fields unchanged.
  - **Optional stretch:** Open a small manage dialog first (list existing templates from `referenceData.shiftTemplates` + "Create new") — only if low effort; otherwise defer to a later prompt.
- Ensure Work queues toolbar button opens `_showWorkQueueDialog` with the **last selected queue** (or default `unassignedShifts` / first non-empty queue from summary counts).

### 2. Notifications submenu — clickable, not hover-fragile

In `app_workspace_toolbar.dart` (`_ToolbarNotificationsSubmenu`):

- Replace hover-only open with **click-to-open** (or click + stable hover bridge).
- Keep submenu open while pointer travels from parent overflow item to child items (use `MenuAnchor` parent/child linkage or a single merged menu level).
- Each notification row must be easy to tap/click on web and desktop; minimum 48px row height preserved.
- Selecting an item runs existing `onSelected` (e.g. `_applyQueueAndShow`) and closes menus.
- Do not regress mobile overflow behavior.

### 3. Work queues dialog — labeled switcher and live content

In `_HrWorkQueuePanel`:

- Extract queue switcher into a reusable widget (e.g. `hr_queue_switcher.dart` under `presentation/widgets/`).
- **Large screens (md+):** show icon **+ label** buttons (or segmented control) for:
  - Leave requests
  - Swap requests
  - Roster drafts
  - Unassigned shifts
  - Payroll drafts
- **Compact screens:** icon-only with tooltips/semantics.
- Active queue visually distinct (selected tone, disabled press on current queue).
- On queue change: `controller.applyQueue(queue)` → table shows loading → renders items or empty state for **that** queue; panel `description` updates to queue name.
- Remove redundant footer **Close** button; rely on header ✕ (same for activity dialog).
- Wire row actions and empty states per queue type (existing `_workItemActions`); verify backend data for demo seed so at least one queue can show items in dev.

### 4. Staff directory table polish

- Fix **Next action** column: prefer `AppButton.tertiary` link style, flexible width, or `overflow: visible` / wider min width so "Review profile" is not clipped.
- **Department column:** show `departmentName` only; move `departmentDisplayId` to staff detail or copy chip on hover.
- **Role / position column:** hide "Not available" subtitle when practitioner type is null — show primary position only.
- Ensure summary notification UI does **not** overlay the table (summary belongs in toolbar notifications submenu or a dedicated summary strip, not floating over rows).

### 5. Staff detail dialog — layout, maximize, and actions (UI only)

**Dialog shell ([prompt2.md](./prompt2.md)):**

- Fix `AppDialog` so maximize fills viewport and resize works on desktop.
- Staff detail dialog: `scrollable: true`, `maxWidth: 980`, allow vertical/horizontal resize.
- **Remove footer Close** from staff detail, work queues, and HR activity dialogs.

**Header / structure:**

- Single clear title in `AppDialog` header; avoid repeating the same title inside `AppWorkspaceDetailPanel` (use description for staff display ID only).
- Keep edit (pencil) action in panel header.

**Overview section:**

- Reorganize `_HrStaffDetailBody` overview using design-system patterns from peer modules (Communications, Mortuary, Emergency use `AppInfoTileGrid` well).
- Group fields logically:
  - **Identity:** staff number, name
  - **Role:** position, practitioner type (omit tile when empty)
  - **Placement:** department
  - **Dates:** hire date
  - **Account:** linked user as structured sub-lines (name, email, copyable user ID) — not one pipe-separated string
- Tune `maxColumns` / `minItemWidth` for balanced grid; use `borderedTiles` consistently with admin workspaces.

**Staff actions section (organize, do not rewire handlers):**

- Keep existing `onPressed` callbacks and permission gates unchanged in this phase.
- Group actions under clear subheadings inside one `AppActionSection` or multiple titled sections:
  - **Placement:** Assign department, Assign position
  - **Scheduling:** Record availability, Assign shift, Swap shift, Request leave
  - **Payroll:** Compensation, Run payroll
  - **Access:** Assign role, View module access (only when user linked)
- Use `AppPermissionActionList` with consistent `AppButton.secondary` (or tertiary link) styling, aligned grid, `minItemWidth` ~200, `maxColumns` 3 on desktop / 2 on tablet / 1 on mobile.
- Actions remain visible but disabled when `state.isMutating` — no behavior change.

**Record sections below actions** (assignments, leave, availability, shifts, compensation): keep `_SmallRecordSection` titles; ensure spacing matches overview (`theme.spacing.md` between sections).

### 6. HR activity dialog — clarify purpose

- Keep read-only timeline for this pass.
- Ensure `hrActivityDescription` explains: *recent HR updates, roster publishes, and shift changes*.
- Optional: add actor name and tap-to-open related entity if IDs exist in `HrTimelineItem` — only if data is already in API response.
- Remove footer Close; header ✕ only.

### 7. Global standards (mandatory)

- All new/changed strings in `app_en.arb`; run codegen.
- Follow `frontend/.cursor/design-system.mdc`, `ui-workspace.mdc`, `ui-patterns.mdc`.
- Reuse `frontend/lib/shared/*` — no one-off dialog chrome.
- Full theme support (light/dark).
- Responsive: Android, iOS, web, Windows.
- Modal-first: no new routes for these flows.
- RBAC unchanged: existing `AccessRequirement` constants on actions.

---

## Out of Scope (this task)

- Rewiring staff-action mutation flows (assign department form behavior, payroll processing, etc.) — **Phase 2** after UI lands.
- Full schedule-template CRUD/list management (unless trivial list wrapper).
- Backend schema/API changes unless required to fix queue data not loading.
- Patient/clinical flows.
- `AppDialog` visual redesign beyond sizing/maximize ([prompt2.md](./prompt2.md) owns shell behavior).

---

## Key Files

```
frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart
frontend/lib/features/hr/presentation/widgets/          — new extract targets
frontend/lib/features/hr/presentation/controllers/hr_workspace_controller.dart
frontend/lib/shared/components/app_dialog.dart          — prompt2.md
frontend/lib/shared/layout/app_workspace_toolbar.dart   — notifications submenu
frontend/lib/shared/actions/app_action_panel.dart
frontend/lib/shared/components/app_info_tile.dart
frontend/lib/l10n/app_en.arb
frontend/test/shared/components/app_dialog_test.dart
```

**Reference implementations:** `communications_workspace_page.dart`, `subscriptions_workspace_page.dart` (toolbar + detail density), `mortuary_workspace_page.dart` (`AppInfoTileGrid` layout).

---

## Acceptance Criteria

### Toolbar
- [ ] Work queues is a visible labeled toolbar button on md+ desktop.
- [ ] Schedule-template button label matches behavior ("Create schedule template" or manage+create if implemented).
- [ ] Notifications submenu items are reliably clickable without disappearing on pointer move.

### Work queues
- [ ] Queue switcher shows labels on large screens, icons on compact.
- [ ] Switching queues updates title/description, loading state, table rows, and empty state correctly.
- [ ] No duplicate Close in dialog footer.

### Staff directory
- [ ] "Review profile" not truncated on standard desktop width.
- [ ] Department column shows name without raw DEP- ID clutter.
- [ ] No summary card overlapping table body.

### Staff detail
- [ ] Dialog maximizes to full viewport and resizes smoothly (per prompt2.md).
- [ ] Overview fields grouped and visually balanced; linked user readable.
- [ ] Staff actions grouped by category with consistent button styling; handlers unchanged.
- [ ] No duplicate Close in footer; no duplicate "Staff detail" title.

### HR activity
- [ ] Description makes purpose clear; footer Close removed.

### Quality
- [ ] `dart format`, `flutter analyze`, `flutter test` pass from `frontend/`.
- [ ] Manual QA: `.\tool\run_web_5201.ps1` → `/hr` → toolbar → work queues (switch all tabs) → notifications → open staff → resize/maximize → scan overview and actions.

---

## Suggested Implementation Order

1. **AppDialog sizing/maximize** — land [prompt2.md](./prompt2.md) first (shared fix benefits all HR dialogs).
2. **Toolbar** — rename create-template label, tune `maxVisibleScreenActions`, fix notifications submenu interaction.
3. **Work queues** — extract switcher widget, responsive labels, remove footer Close, verify queue refresh.
4. **Staff directory** — column content and next-action truncation; summary overlap fix.
5. **Staff detail** — overview layout, action grouping, dedupe titles, remove footer Close.
6. **HR activity** — copy tweak, footer Close removal.
7. **L10n + tests** — arb updates, widget test for queue switcher and/or toolbar submenu if feasible.

---

## Deliverable

A focused HR workspace UI pass: honest toolbar labels, stable notifications menu, labeled work-queue navigation with live data, polished staff directory columns, and a staff-detail dialog that maximizes/resizes correctly with organized overview and grouped action buttons — ready for a follow-up phase to refine staff-action workflows.
