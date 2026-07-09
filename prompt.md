# Dashboard UI polish (shared components)

Refine the HOSSPI home dashboard so it looks clean, consistent, and professional across **all roles and screen sizes** (mobile, tablet, desktop). Only **content** may differ per role; **layout and styling** must be identical and driven by shared components.

**Scope:** `frontend/lib/shared/dashboard/` only. Role-specific data stays in feature mappers (`home_dashboard_mapper.dart`, `home_dashboard_layout.dart`).

---

## Goals

1. **Visual uniformity** — Every role dashboard should feel like the same product; only metrics, actions, queue items, and charts change.
2. **Simplicity** — Minimal chrome, clear hierarchy, no cramped or misaligned rows.
3. **Responsive stability** — Card counts of 2, 3, or 4 must produce equally balanced grids (no odd sizing when counts differ).

---

## Required changes

### 1. Summary metric cards (`dashboard_metric_strip.dart`)

**Current:** Icon left; label above value in a column.

**Target layout (single row):**

```
[icon]  [value]  [label]                    [chevron if tappable]
```

- Icon in accent container on the left.
- **Value** (quantity) immediately after the icon — prominent, accent color.
- **Label** on the same row after the value — smaller, muted.
- Chevron stays trailing when the card is actionable.

**Grid behavior:**

- Honor `maxCards` / role `effectiveMaxStatusCards` (2–4 cards).
- At desktop widths, distribute cards evenly across the row regardless of count (2, 3, or 4) so card widths stay consistent within a tier.
- Avoid layouts where 2 or 3 cards look stretched or mis-sized compared to 4-card dashboards.
- Preserve compact mode for smaller breakpoints.

### 2. Quick actions (`dashboard_quick_actions.dart`)

**Current:** Plain `Wrap` of `AppButton.secondary` — visually weak and uneven.

**Target:**

- Polished horizontal action strip: equal-height chips or outlined action tiles with icon + label.
- Consistent padding, spacing, and alignment; actions should not wrap awkwardly on desktop.
- On narrow screens, wrap gracefully (2-per-row or stacked) without clipping labels.
- Reuse theme tokens (`spacing`, `radius`, `colorScheme`); match the metric card visual language.

### 3. Worklist / recent-activity rows (`dashboard_priority_panel.dart` → `_DashboardWorklistRow`)

**Current:** Title on one line; date/subtitle drops to a second line, making rows tall and uneven.

**Target (single row):**

```
[icon]  [title · date]                              [status badge]
```

- Keep title and subtitle (e.g. `ADM-FFB3ED423B · Jul 7, 15:23`) on **one line** with ellipsis overflow.
- Status badge stays trailing, vertically centered with the row.
- Row height should be uniform across Admissions, Lab Results, etc.

### 4. No changes needed

- Alerts panel (empty quiet state with checkmark).
- Shortcut tiles (Subscriptions, Reports).
- Charts row (`dashboard_charts_row.dart`).

---

## Constraints

- Do **not** duplicate dashboard UI per role — fix at the shared component level.
- Use existing models (`DashboardMetricCardData`, `DashboardQuickActionData`, `DashboardWorklistItemData`) and `RoleDashboardScaffold` section order.
- Follow project theme extensions and breakpoints (`AppBreakpoints`).
- Keep semantics labels intact for accessibility.
- Run existing dashboard tests; add/adjust tests only if layout logic changes materially.

---

## Acceptance criteria

- [ ] Metric cards show icon → value → label on one row at all breakpoints.
- [ ] 2-, 3-, and 4-card dashboards produce balanced, same-width cards on desktop.
- [ ] Quick actions look styled and aligned, not like raw text buttons.
- [ ] Worklist rows keep title + date on one line; no subtitle line-break.
- [ ] Super Admin, clinical, and department dashboards share the same visual shell; only data differs.
- [ ] Layout remains usable on mobile (320px+), tablet, and desktop.
