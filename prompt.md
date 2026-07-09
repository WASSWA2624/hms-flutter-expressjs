# HOSSPI Dashboard — Visual Refinement Brief

## Goal

Redesign the role-based dashboard so it feels **simple, uniform, and clear** at a glance: what is happening now, what needs attention, and what to do next. The dashboard should invite further navigation — not overwhelm with dense lists and visually similar blocks.

## Scope

Shared dashboard shell used by all roles via `RoleDashboardScaffold`:

`summary badges → quick actions → priority worklist → charts`

**Primary files:** `frontend/lib/shared/dashboard/` — especially `role_dashboard_scaffold.dart`, `dashboard_metric_strip.dart`, `dashboard_quick_actions.dart`, `dashboard_priority_panel.dart`, `dashboard_charts_row.dart`, `dashboard_layout.dart`.

**Data wiring stays unchanged** — refine layout, hierarchy, spacing, and presentation only (`home_dashboard_mapper.dart` and role configs should not need structural changes).

---

## Problems (from current UI)

1. **Summary cards and quick actions look too alike** — both use similar bordered cards with icon + label, so the top of the page reads as one undifferentiated strip.
2. **Sections lack clear partitioning** — worklist, alerts, shortcuts, and charts blend together; only some panels have titles.
3. **Dashboard feels congested** — tight vertical rhythm, long single-line rows (e.g. `Admissions ADM-FFB3ED423B · Jul 7, 15:23`), and too much visible at once.
4. **Summary row behavior on desktop** — on large screens, all metric cards must share **one full-width row** with equal widths (2, 3, or 4 cards), not wrap or stack.

---

## Design Requirements

### 1. Summary metric strip (top — no section title)

- **Desktop (≥1180px):** all visible cards (2–4) on a **single row**, equal width, spanning full content width.
- **Tablet (760–1179px):** up to 2 per row.
- **Mobile:** 1–2 per row as space allows.
- Cards remain **read-only glance metrics** (value + short label + accent icon).
- Visually distinct from actions below: lighter surface, compact height, no button-like affordance unless `onTap` is set.

### 2. Quick actions (first titled section)

- Add a **short section title** (e.g. *Next steps*, *Actions*, or role-specific label from data).
- Visually **separate from metrics**: more vertical spacing above, and a clearly different treatment — e.g. filled/primary-tinted buttons or prominent CTA tiles, not metric-card clones.
- Desktop: all actions on one row with equal width (same column logic as metrics).
- Examples from screenshots:
  - Clinical: *Start consultation*, *Continue consultation*
  - Platform admin: *Select tenant/facility*, *Create tenant*, *Create facility*

### 3. Priority / work area (titled subsections)

Each subsection gets a **short, scannable title**:

| Subsection | Example title | Content |
|---|---|---|
| Work queue | *Recent activity*, *Your queue* | Top 3 items max; *View all* link |
| Alerts | *Critical alerts* | Top 3 items or quiet empty state |
| Shortcuts | *Quick links* | Emergency, Laboratory, Subscriptions, Reports, etc. |

**Worklist rows** — simplify presentation:

- Lead with **human-readable type** (Admissions, Lab results) — de-emphasize or truncate long IDs.
- Secondary line or muted suffix for timestamp, not one overcrowded line.
- Status badge remains right-aligned; reduce row density (more padding, fewer competing text weights).

**Empty states** (e.g. platform admin *Choose a tenant to view operational dashboards*) — centered, calm, with a single clear CTA; not buried in a generic panel.

### 4. Charts (titled subsection)

- Keep existing chart panels; ensure consistent section title styling with priority subsections.
- Desktop: side-by-side where `twoColumns` is enabled; mobile: stacked.
- Preserve empty-state messaging for zero data.

### 5. Spacing, rhythm, and hierarchy

- Increase **vertical gap between major sections** (metrics → actions → priority → charts).
- Use a consistent **section header pattern** (title + optional icon) for everything except the metric strip.
- Limit visible items per list (3 queue, 3 alerts) — detail lives behind *View all*.
- Reuse `AppSpacingTokens`, `AppBreakpoints`, and `AppSectionPanel` / theme tokens — no one-off colors or magic numbers.

---

## Acceptance Criteria

- [ ] On desktop, 2–4 summary cards always render on **one equal-width row**.
- [ ] Summary cards and quick actions are **immediately distinguishable** in style and spacing.
- [ ] Every section below the metric strip has a **visible short title**.
- [ ] Worklist rows are **less dense** and easier to scan than the current single-line format.
- [ ] Dashboard feels **airier** — no section visually merges with the next.
- [ ] Responsive behavior holds on mobile, tablet, and desktop.
- [ ] Existing widget tests in `frontend/test/shared/dashboard/` pass; add/update layout tests for column counts and section structure as needed.
- [ ] No regressions across role variants (clinical, platform admin, and other roles using `RoleDashboardScaffold`).

---

## Non-Goals

- Changing dashboard data sources, API contracts, or navigation targets.
- Adding new dashboard sections or role-specific business logic.
- Redesigning the app shell (sidebar, header, notifications).
