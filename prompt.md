# Dashboard worklist & action polish

Polish the shared role dashboard template for worklist rows, quick-action buttons, queue panel headers, and the alerts empty state. **Do not change chart widgets, metric strip layout, or data/routing logic.**

**Primary files:** `frontend/lib/shared/dashboard/dashboard_quick_actions.dart`, `frontend/lib/shared/dashboard/dashboard_priority_panel.dart`, `frontend/lib/shared/components/app_button.dart`, `frontend/lib/features/home/domain/entities/home_dashboard_layout.dart`, `frontend/lib/features/home/presentation/widgets/home_dashboard_mapper.dart`.

---

## Context (current state — keep as-is)

- Metric strip, quick-actions panel container, section backgrounds/borders, and charts are correct.
- Quick actions: horizontal button row inside a bordered `AppSectionPanel`.
- Queue panel uses `AppSectionPanel` with list icon + “View all” when populated.

---

## 1. Quick action buttons — add faint border

**Issue:** Primary action buttons (e.g. *Receive sample*, *Enter lab result*) have no visible edge; button boundaries are unclear.

**Required:**

- Add a **subtle border** to each quick-action button (not a fill/background change).
- Use theme tokens: `outlineVariant` at ~0.7 alpha, matching shortcut tiles and dashboard section borders.
- Preserve current label, icon, padding, responsive row layout, and semantics.
- Apply via `AppButton` or `_DashboardQuickActionTile` — whichever keeps styling consistent app-wide.

---

## 2. Queue / worklist panel — show section title

**Issue:** The worklist panel (e.g. lab results list) shows only a list icon in the header — no title text — unlike **Quick actions** and **Alerts**, which display icon + title.

**Required:**

- Show a **visible section title** beside the header icon when the queue panel has items (e.g. *Lab queue* for lab tech via `homeQueueTitle(role)`).
- Enable or fix `showQueuePanelTitle` in `HomeDashboardProfile` / mapper so `queueTitle` is passed to `_DashboardQueuePanel` when the panel is populated.
- Keep empty-state behavior: message inline with icon when the queue is empty.
- “View all” trailing action unchanged.

---

## 3. Worklist row layout — icon + title, details on next line

**Issue:** Rows such as *Lab Results* / `LBR-… · Jul 7, 15:23* / *Abnormal* need clearer hierarchy.

**Required layout per row:**

```
[icon]  Lab Results
        LBR-4ECC7E0442 · Jul 7, 15:23          [Abnormal]
```

- **Line 1:** Item icon + headline title (e.g. *Lab Results*) on the same row.
- **Line 2:** Reference and timestamp on the next line, **indented to align with the headline text** (not under the icon). Prefix with a colon if needed: `LBR-… · Jul 7, 15:23`.
- **Preserve** existing font sizes, weights, and colors for headline (`titleSmall` bold) and detail (`bodySmall`, `onSurfaceVariant`).
- Update `_DashboardWorklistRow` and `_parseWorklistTitle` / `_worklistDetailLine` in `dashboard_priority_panel.dart`; reuse for both queue items and alert items.

---

## 4. Status badge — inset from panel edge

**Issue:** Status labels (e.g. *Abnormal*) sit flush against the panel border with insufficient padding.

**Required:**

- Add horizontal spacing so the trailing status badge (`AppWorkspaceStatusBadge`) does not touch the panel border.
- Ensure the badge row has comfortable inset on the right (and between badge and detail text).
- Do not change badge colors or typography — only spacing/inset.

---

## 5. Alerts empty state — green “All clear”

**Issue:** When there are no alerts, *All clear* uses neutral gray styling; it should read as a positive/success state.

**Required:**

- Update `_DashboardQuietState` to use **success/green** styling when the alerts list is empty.
- Use theme status colors (`statusColors.success` / `AppWorkspaceStatusTone.success`) for icon and text — consistent with other success indicators in the app.
- Keep copy as *All clear*; no layout changes to the alerts panel header.

---

## Out of scope

- Charts row (sample throughput trend, test mix donut).
- Metric strip and quick-actions section panel wrappers.
- Quick links section.
- l10n string changes (unless a title key is missing for a role).

---

## Acceptance criteria

- [ ] Quick-action buttons have a faint visible border; no unintended background change.
- [ ] Populated queue panel shows icon + section title (e.g. *Lab queue*) like Alerts and Quick actions.
- [ ] Worklist rows: icon + title on line 1; reference/timestamp indented on line 2; fonts/colors unchanged.
- [ ] Status badge has adequate padding and does not touch the panel edge.
- [ ] Alerts empty state shows green success styling for *All clear*.
- [ ] `flutter analyze` clean; existing dashboard tests pass.
