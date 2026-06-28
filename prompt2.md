# Workspace Summary Cards → More Actions Notifications Submenu

## Objective

Remove the **summary card grid** from all module workspace screens and relocate the same queue/count shortcuts into a **Notifications** nested submenu inside the workspace **More actions** overflow menu. Users filter the worklist by selecting a notification item — behavior must match today’s summary-card taps. Delete the summary-card UI components and all dead wiring once migration is complete.

**Manual smoke URL:** `127.0.0.1:5201` — verify on OPD, Lab, Billing, ICU, and one operational module (e.g. Housekeeping).

---

## Problem summary (current behavior)

### 1. Summary cards consume vertical space

`AppWorkspace` renders an `AppWorkspaceSummaryGrid` below the header whenever `summaryCards` is non-empty (hidden only on `xs` / `sm` breakpoints):

| Layer | Location | Issue |
|-------|----------|-------|
| Grid shell | `AppWorkspaceSummaryGrid` in `app_workspace.dart` | Occupies a full row between header and filters/worklist on tablet/desktop. |
| Card widget | `AppWorkspaceSummaryCard` | Large interactive tiles with icon, label, count badge, hover/press animation. |
| Per-page builders | `*_workspace_page.dart` (`_summaryCards`, `_opdBackendSummaryCards`, etc.) | Each module builds `List<Widget>` of cards and passes them to `AppWorkspace`. |

Roughly **30 workspace pages** pass `summaryCards` / `compactSummaryCards: true`.

### 2. Counts are already toolbar-adjacent

Summary cards duplicate information that belongs with workspace actions. The product intent is to **declutter the worklist** and surface counts only on demand via **More actions**.

### 3. More actions menu lacks nested sections

`_ToolbarOverflowMenu` in `app_workspace_toolbar.dart` renders a flat `PopupMenuButton<int>` list via `AppToolbarOverflowEntry` + `AppMenuItemLabel` (icon + label only). There is no submenu pattern for grouped notification shortcuts.

### 4. More actions trigger cursor

`AppButton.popupMenuTrigger` (used as the More actions child) does not set `SystemMouseCursors.click`. The trigger should show a **pointer** cursor on hover so it reads as interactive.

### 5. Documentation still mandates inline summary cards

`frontend/.cursor/ui-workspace.mdc` and `.cursor/flows/opd-flow.mdc` §6 require compact summary cards on workspaces. These rules must be updated after migration.

---

## Target UX (all breakpoints)

### Remove from workspace body

- No `AppWorkspaceSummaryGrid` row anywhere in module workspaces.
- No `summaryCards`, `compactSummaryCards`, or `inlineSummaryCards` parameters on `AppWorkspace`.
- Worklist starts immediately after header (+ optional filter bar).

### Notifications submenu in More actions

On every workspace that currently exposes summary cards, the **More actions** menu (`context.l10n` / existing overflow label) includes a top-level item:

```
┌ More actions ─────────────────────┐
│ ↻ Refresh                         │
│ 🔔 Notifications              ▸   │  ← opens nested submenu
│ … other overflow actions …        │
└───────────────────────────────────┘
```

Selecting **Notifications** opens a **nested submenu** (flyout to the side on desktop; acceptable stacked/submenu pattern on narrow viewports) listing the same items that were summary cards.

### Notification row layout

Each submenu row:

```
[ color-coded icon ]  Label text ……………………  Count
```

| Element | Rule |
|---------|------|
| **Icon (left)** | Same `IconData` as the former summary card. **Color-coded** via `AppWorkspaceStatusTone` → theme accent (`success`, `warning`, `error`, `info`, `neutral`) — reuse `_summaryAccentColor` logic or extract a shared helper before deleting card widgets. |
| **Label (center)** | Same localized label as the former card (`opdSummaryCountLabel`, module l10n keys, etc.). Ellipsis on overflow. |
| **Count (right)** | Compact numeric badge (same compact number formatting as cards: `AppFormatters.compactNumber`). Right-aligned; use existing `_SummaryValueBadge` styling **or** extract a small shared `AppMenuCountBadge` before removing card-only code. |
| **Zero counts** | **Omit** rows where count ≤ 0 — same rule as today’s `if (value <= 0) return` in OPD and other modules. |
| **Tap behavior** | Invoke the **same callback** the summary card’s `onPressed` used (typically apply worklist filter / category / stage). Must **filter the worklist**, not open a modal list ([`ui-workspace.mdc`](frontend/.cursor/ui-workspace.mdc)). |
| **Selected state** | Optional: visually indicate the active filter if the module already tracks selected summary category (e.g. OPD `_OpdTableFilter`). Do not block migration if this requires a follow-up. |

### More actions trigger

- Hovering the More actions (`Icons.more_vert`) trigger shows **`SystemMouseCursors.click`** (pointer finger).
- Apply via `MouseRegion` on the trigger or inside `AppButton.popupMenuTrigger` when `onPressed == null` (PopupMenuButton child pattern).

### Empty notifications

If all counts are zero (no submenu rows), either:

- Hide the **Notifications** parent menu item entirely, **or**
- Show it disabled with tooltip “No active notifications” (prefer **hide** for consistency with hidden zero cards).

---

## Scope

### In scope

| Area | Location |
|------|----------|
| Workspace shell | `frontend/lib/shared/layout/app_workspace.dart` — remove grid/cards; keep unrelated workspace widgets (`AppWorkspaceStatusBadge`, detail panels, etc.) |
| Toolbar overflow | `app_workspace_toolbar.dart`, `app_toolbar_overflow_resolver.dart` |
| New shared model + menu UI | e.g. `AppWorkspaceSummaryNotification`, `AppWorkspaceNotificationsSubmenu` under `frontend/lib/shared/layout/` |
| Menu row component | Extend `AppMenuItemLabel` or add `AppMenuItemLabelWithCount` (icon + label + trailing count badge) |
| Toolbar config | `AppWorkspaceToolbarConfig` — add `summaryNotifications` (or equivalent) |
| All module workspace pages passing `summaryCards` | OPD, Lab, Pharmacy, Billing, ICU, IPD, Nursing, Emergency, Discharge, Claims, Clinical, Operations, Housekeeping, Subscriptions, Tenant Facility setup, etc. |
| l10n | `app_en.arb` — e.g. `workspaceNotificationsMenuLabel` |
| Cursor fix | `AppButton.popupMenuTrigger` |
| Tests | `frontend/test/shared/layout/app_workspace_test.dart`, new toolbar/submenu tests |
| Cursor rules | `frontend/.cursor/ui-workspace.mdc`, `.cursor/flows/opd-flow.mdc` §6 |

### Out of scope

- **Settings hub** summary tiles (`_SettingsSummaryCards`, `SettingsSummaryCard` entity) — different layout; migrate separately if desired.
- **Shell notifications bell** in `responsive_shell_scaffold.dart` — unrelated global inbox.
- **Domain entities** named `*SummaryCard` in data layers (e.g. `HousekeepingSummaryCard`, `ReportsSummaryCard`) unless only used for deleted UI; keep DTOs if API still returns them.
- Changing count APIs, backend aggregates, or filter logic — **relocate UI only**; preserve existing controller methods.

---

## Implementation strategy

Work in this order. **Shared components first**, then migrate modules in batches.

### Phase 1 — Add notifications submenu infrastructure

1. **Define immutable notification item**:

   ```dart
   @immutable
   final class AppWorkspaceSummaryNotification {
     const AppWorkspaceSummaryNotification({
       required this.label,
       required this.count,
       required this.icon,
       required this.onSelected,
       this.tone = AppWorkspaceStatusTone.neutral,
     });
     // hide when count <= 0 via factory or caller filter
   }
   ```

2. **Add `summaryNotifications` to `AppWorkspaceToolbarConfig`** (default `const []`).

3. **Build nested submenu UI** in `_ToolbarOverflowMenu` (or extracted widget):
   - Prefer Flutter **`MenuAnchor` + `SubmenuButton`** (or project-consistent pattern) over flat `PopupMenuButton` if nested menus are required.
   - Parent item: notifications icon + “Notifications” label + chevron.
   - Child items: one row per non-zero notification using shared row layout (icon | label | count).

4. **Extend `AppMenuItemLabel`** (or sibling widget) with optional trailing `count` + `AppWorkspaceStatusTone` for icon color.

5. **Wire module data**: each workspace converts its `_summaryCards` builder into `List<AppWorkspaceSummaryNotification>` passed via `toolbar: AppWorkspaceToolbarConfig(summaryNotifications: …)`.

### Phase 2 — Remove summary card UI from `AppWorkspace`

1. Delete from `app_workspace.dart`:
   - `AppWorkspaceSummaryGrid`
   - `AppWorkspaceSummaryCard` and private helpers (`_SummaryCardBody`, `_SummaryValueBadge`, `_summaryCardShadow`, `_summaryAccentColor` if not extracted)
2. Remove constructor params: `summaryCards`, `compactSummaryCards`, `inlineSummaryCards`.
3. Remove grid insertion block in `AppWorkspace.build` (lines ~150–165).
4. Export new types from `layout.dart` barrel if applicable.

### Phase 3 — Migrate workspace pages

For each page that currently sets `summaryCards`:

1. Remove `summaryCards` / `compactSummaryCards` from `AppWorkspace(...)`.
2. Move card definitions to `summaryNotifications` on `appWorkspaceToolbarWithLabels` / `AppWorkspaceToolbarConfig`.
3. Replace `AppWorkspaceSummaryCard(... onPressed: () => _applyFilter(...))` with `AppWorkspaceSummaryNotification(... onSelected: () => _applyFilter(...))`.
4. Delete private `_summaryCards` / `_summaryCard` helpers that only existed for widgets.
5. **Reference migration:** start with **OPD** (`opd_workspace_page.dart` — `_opdBackendSummaryCards`), then Lab, Billing, ICU; batch the remainder.

### Phase 4 — Pointer cursor on More actions

1. Update `AppButton.popupMenuTrigger` (or `_ToolbarOverflowMenu` wrapper) so the trigger shows `SystemMouseCursors.click` on hover when used as a menu opener (`onPressed == null`).

### Phase 5 — Cleanup & docs

1. Grep confirm zero usages: `summaryCards:`, `AppWorkspaceSummaryCard`, `AppWorkspaceSummaryGrid`, `compactSummaryCards`.
2. Update `ui-workspace.mdc`: replace “summary cards filter worklist” with “notifications submenu in More actions filters worklist”.
3. Update `opd-flow.mdc` §6: remove “compact summary cards”; reference notifications submenu.
4. Remove or rewrite tests that assert summary grid rendering in `app_workspace_test.dart`; add tests for submenu visibility, zero-count hiding, and filter callback invocation.

---

## Acceptance criteria

- [ ] **No summary card grid** renders on any migrated module workspace at any breakpoint.
- [ ] **`AppWorkspaceSummaryCard` and `AppWorkspaceSummaryGrid` are deleted** (or moved out and deleted if temporarily extracted); no dead imports remain.
- [ ] **More actions → Notifications** nested submenu lists all non-zero summary counts for that module.
- [ ] Each submenu row shows **color-coded icon**, **label**, and **count** on the right.
- [ ] **Tapping a notification applies the same worklist filter** as the former summary card (verified on OPD at minimum).
- [ ] **Zero-count items are hidden** (parent Notifications item hidden when all counts are zero).
- [ ] **More actions trigger** shows pointer cursor on hover.
- [ ] **l10n** used for “Notifications” menu label; no hard-coded strings.
- [ ] `dart analyze` passes on touched files; updated/added widget tests pass.
- [ ] Cursor rule docs (`ui-workspace.mdc`, `opd-flow.mdc` §6) reflect the new pattern.

---

## Verification

1. **Automated:** `flutter test frontend/test/shared/layout/app_workspace_test.dart` and new submenu tests.
2. **Static:** repo grep returns **zero** `summaryCards:` on workspace pages; zero `AppWorkspaceSummaryCard` references outside git history.
3. **Manual (OPD):** open OPD workspace → confirm no card row below header → open More actions → Notifications → pick “Active OPD” (or equivalent) → worklist filters; count matches previous card behavior.
4. **Manual (cursor):** hover More actions button → pointer cursor visible.
5. **Manual (responsive):** spot-check at **626px** and **desktop** — submenu usable; worklist not pushed down by removed grid.

---

## Constraints

- **Minimize diff scope** — shared menu infrastructure first; migrate pages in batches by module.
- **Preserve behavior** — counts, filters, refresh-after-mutation, and hide-zero rules unchanged; UI relocation only.
- **Follow existing conventions** — `AppWorkspaceStatusTone`, `AppFormatters.compactNumber`, `context.l10n`, theme spacing/tokens; no hard-coded colors.
- **No new dependencies.**
- **Do not** change Settings hub summary tiles in this pass unless explicitly expanded.
- **Summary cards must still filter the worklist, not open modals** — same product rule, new entry point.
