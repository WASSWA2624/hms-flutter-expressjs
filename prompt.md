# Dashboard admissions row & metric label polish

Two targeted refinements to the shared role dashboard. **Everything else is correct — do not change it.**

**Primary files:** `frontend/lib/shared/dashboard/dashboard_priority_panel.dart`, `frontend/lib/shared/dashboard/dashboard_metric_strip.dart`.

---

## Context (keep as-is)

- Metric strip layout (`[icon] [value] [label]` single row on desktop/tablet).
- Quick actions panel, button borders, section backgrounds.
- Queue panel header (icon + title, e.g. *Actions*).
- Alerts *All clear* green styling, status badge inset, charts, and quick links.

---

## 1. Worklist row — single-line headline + reference

**Current issue:** Admissions rows split content across two lines — *Admissions* on line 1, `ADM-FFB3ED423B · Jul 7, 15:23` indented on line 2.

**Required layout (one line after the icon):**

```
[icon]  Admissions  ADM-FFB3ED423B · Jul 7, 15:23          [Admitted]
```

- **Headline** (e.g. *Admissions*, *Lab Results*): keep `titleSmall`, bold — same as today.
- **Reference + timestamp** (`ADM-… · Jul 7, 15:23`): keep `bodySmall`, `onSurfaceVariant` — same font size/color as the current detail line.
- Place headline and reference/timestamp on the **same horizontal row**, separated by a small gap (e.g. `theme.spacing.xs`).
- Remove the second-line indent layout from `_DashboardWorklistRow`; apply to all worklist rows (queue + alerts).
- Truncate with ellipsis if the row overflows; status badge stays trailing with existing inset.

Update `_DashboardWorklistRow`, `_parseWorklistTitle`, and `_worklistDetailLine` as needed.

---

## 2. Worklist row — increase horizontal padding

**Current issue:** Row content sits too close to the panel left/right edges, especially on hover.

**Required:**

- Add comfortable **horizontal inset** to each worklist row so text and badges do not feel flush with the panel border.
- Use theme spacing tokens (e.g. `theme.spacing.sm` or `md` on left and right of row content).
- Preserve vertical spacing and tap targets; do not reduce the status-badge right inset added previously.

---

## 3. Summary metric cards — slightly larger labels

**Current issue:** Metric labels (*Facilities*, *Users*, *Adoption*, *Patient flow*) use `labelSmall`, which is hard to read for users with sight difficulties.

**Required:**

- Increase label text size **one step** — e.g. from `labelSmall` to `labelMedium` or `bodySmall`.
- Labels must remain **visibly smaller than** the metric value (`headlineSmall` / `titleLarge`).
- Keep label color (`onSurfaceVariant`), weight, and single-line truncation.
- Apply in `_DashboardMetricCard` only; do not change value styling or card layout.

---

## Out of scope

- Quick actions, alerts panel, charts row, quick links.
- Data sources, routing, l10n, or role profile logic.
- Queue panel title, empty states, or section panel wrappers.

---

## Acceptance criteria

- [ ] Worklist rows show icon + headline + reference/timestamp on one line; detail text keeps `bodySmall` styling.
- [ ] Worklist rows have increased left/right padding inside the panel.
- [ ] Metric labels are slightly larger but still smaller than metric values.
- [ ] `flutter analyze` clean; existing dashboard tests pass.
