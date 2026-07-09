# Dashboard section visual containment

Add subtle panel styling to two dashboard sections so their boundaries are easy to see against the page background. **Layout, copy, and behavior are already correct — do not change them.**

**Primary files:** `frontend/lib/shared/dashboard/dashboard_quick_actions.dart`, `frontend/lib/shared/dashboard/dashboard_priority_panel.dart`, and (if needed) `frontend/lib/shared/components/app_content_panel.dart`.

---

## Context (current state)

The dashboard scaffold order is: metric strip → **Quick actions** → **priority / empty-state panel** → Quick links → Charts.

Per the screenshot, the following are **done and must stay as-is**:

- Metric cards: single row on desktop/tablet; `[icon] [value] [label]` inline.
- Quick actions: horizontal button row (max 4) on wide screens; “Quick actions” title.
- Empty-state panel: message inline with header icon; no large decorative icon; action buttons in a row on wide screens.
- Quick links and charts: unchanged.

---

## 1. Quick actions — add faint panel background

**Issue:** The Quick actions block (title + buttons) sits directly on the page background with no visible container, so the section start/end is unclear.

**Required:**

- Wrap the **entire** Quick actions section (header + button row) in a subtle contained panel.
- Use existing design tokens — prefer `AppContentPanel` / `AppSectionPanel` or the same decoration as metric cards (`surfaceContainerLowest` fill + light `outlineVariant` border + `theme.radius.lg`).
- Background should read as a **faint white / elevated surface**, not a heavy card.
- Preserve current padding, spacing, responsive button layout, and semantics.
- Match visual weight to other dashboard panels (Quick links, charts) for UI uniformity.

---

## 2. Priority / empty-state panel — strengthen boundary

**Issue:** The panel showing *“Choose a tenant to view operational dashboards”* (and its action button) needs clearer visual containment.

**Required:**

- Ensure this panel has a **visible but subtle** boundary — faint background and/or border — so users can see where the section starts and ends.
- Reuse `AppSectionPanel` styling; do **not** reintroduce the removed large centered empty-state icon.
- Keep the message inline with the list header icon.
- Empty-state action buttons remain in `DashboardActionButtonRow` layout.
- Apply consistently when the queue panel is empty across roles, not only for the super-admin tenant prompt.

---

## 3. Out of scope

- Metric strip layout or styling (unless spacing against new panels needs a minor tweak).
- Quick links section.
- Charts row.
- Data, routing, l10n strings, or role profile logic.

---

## Acceptance criteria

- [ ] Quick actions section has a faint panel background/border that clearly frames title + buttons.
- [ ] Empty-state / priority queue panel has a clearly visible but subtle container boundary.
- [ ] Styling uses theme tokens (no hard-coded colors); consistent with other dashboard panels.
- [ ] Responsive layouts unchanged: single-row buttons on desktop/tablet, stacked on mobile.
- [ ] `flutter analyze` clean; existing dashboard tests still pass.
