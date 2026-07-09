# Reusable Role Dashboard Component

## Objective

Extract the home dashboard into a **reusable shared component** so every role uses the same shell and only supplies role-specific data. The layout must be uniform across all users — clear visual separation between sections, consistent spacing, and identical styling for interactive elements.

**Move from:** `frontend/lib/features/home/presentation/widgets/home_dashboard_scaffold.dart`  
**Move to:** `frontend/lib/shared/dashboard/` (export via `shared/dashboard/dashboard.dart`)

**Standards:** `frontend/.cursor/design-system.mdc`, `components.mdc`, `layouts.mdc`. All labels via `app_en.arb`. Responsive on mobile, tablet, and desktop. Reuse `AppButton`, `AppSectionPanel`, `AppResponsiveWrap`, and existing theme tokens before adding new widgets.

---

## Dashboard Shell

Provide one scaffold widget (e.g. `RoleDashboardScaffold`) with **no page title** and **no refresh button**. Consumers pass data; the shell owns layout only.

### Section order (fixed for all roles)

| # | Section | Purpose | Rules |
|---|---------|---------|-------|
| 1 | **Summary badges** | Role-specific KPI cards (waiting patients, pending labs, etc.) | Max 3–4 cards; **always show configured cards, including zero values** (display `0`, not hidden); responsive grid |
| 2 | **Quick actions** | Primary workflow buttons (register patient, start consultation, etc.) | Use shared `AppButton.secondary`; identical size, spacing, and wrap layout everywhere |
| 3 | **Priority worklist** | Items requiring attention (pending patients, critical labs, overdue tasks) | Show priority/severity; cap visible rows (e.g. 3–5); deep-link into target workspace — not duplicate worklists |
| 4 | **Charts** | Trend or distribution visuals (line, pie, donut) | **Max 4** charts; **always render the chart panel** — use empty-state placeholders when no data; responsive 1- or 2-column layout |

Configured sections always render. Individual badges, metrics, and panels **must remain visible at zero** — do not filter out or collapse items solely because the value is `0`. Only omit an entire section when the role has no configured items for that section type.

---

## Reusable building blocks

Create shared, role-agnostic widgets under `frontend/lib/shared/dashboard/`:

| Widget | Responsibility |
|--------|----------------|
| `RoleDashboardScaffold` | Four-section column layout and spacing |
| `DashboardMetricStrip` | Summary badge grid — includes zero-value metrics |
| `DashboardQuickActions` | Styled quick-action button row/wrap |
| `DashboardPriorityPanel` | Queue/alerts list with priority chips and “view all” — show empty state when none pending |
| `DashboardChartsRow` | Up to 4 charts — show empty-state UI when series has no data |

Each widget accepts plain data models (counts, labels, icons, routes, chart series) — **no role logic inside shared code**. Role configuration stays in `home_dashboard_profiles.dart` and the home feature layer.

---

## Data & integration

- Populate sections from `HomeDashboard` + `home_dashboard_profiles.dart` (`statusCards`, `quickActionIds`, `shortcutIds`, queue/alerts, trend/distribution).
- Drill-downs use **modals** or workspace deep-links — never intermediate workflow routes.
- Charts read from `dashboard-workspace` API when available; graceful fallback when empty.

---

## Implementation tasks

1. **Extract shared dashboard module** — Move scaffold and section widgets to `lib/shared/dashboard/`; export from barrel file; update `home_page.dart` imports.
2. **Unify quick actions** — Single `DashboardQuickActions` component used by all roles.
3. **Priority worklist** — Merge queue preview + alerts into `DashboardPriorityPanel`; show priority, cap rows, link to workspace.
4. **Charts** — Consolidate trend/distribution into `DashboardChartsRow` (max 4); always show panel with empty-state when `!hasData`.
5. **Wire home feature** — Map `HomeDashboard` entities into shared widget inputs; keep role profiles as the configuration source.
6. **Responsive QA** — Verify layout at mobile, tablet, and desktop breakpoints.

---

## Acceptance criteria

- [ ] Dashboard shell lives under `frontend/lib/shared/dashboard/`
- [ ] All roles render the same four sections in the same order
- [ ] Quick-action buttons look identical across roles (only labels/icons differ)
- [ ] Priority worklist shows capped, prioritized items — not full module worklists
- [ ] Charts capped at 4; panel always visible with empty-state when no data
- [ ] No dashboard title or refresh button
- [ ] **Zero-value summary badges and metrics still display** (show `0`, never omit)
- [ ] All configured dashboard components render even when counts are zero
- [ ] Strings localized; no analyzer warnings in touched files
- [ ] Existing home dashboard tests updated and passing
