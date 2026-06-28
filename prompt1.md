# Workspace More Actions & Notifications — UX polish

## Objective

The **Notifications** nested submenu inside workspace **More actions** is functionally in place (see `prompt2.md`), but the current presentation is poor: the flyout detaches from its trigger, the menu feels unpolished, and the header/toolbar wastes vertical space. Refine layout, positioning, and affordances so the pattern is compact, obvious, and uniform across all module workspaces.

**Smoke URL:** `127.0.0.1:5201` — verify on **OPD** (primary reference), then Lab, Billing, ICU, and one operational module.

---

## Problems observed (screenshots)

### 1. Notifications submenu is visually disconnected

When **More actions** is opened and **Notifications** is hovered/expanded, the nested flyout appears **far from the parent menu** (often centered in the worklist area) instead of hugging the trigger. This breaks the parent–child relationship and looks like a floating orphan panel over the table.

| Symptom | Likely cause |
|---------|----------------|
| Flyout floats in the middle of the content | `SubmenuButton` / `MenuAnchor` default alignment not constrained to the overflow trigger |
| Hard to trace which menu opened the panel | No visual anchor (shadow overlap, shared edge, or proximity) between parent and child menus |

### 2. Menu design is not production-quality

- Parent **Notifications** row shows **two chevrons** (duplicate trailing affordance).
- Row density, padding, and icon alignment do not match the rest of the app chrome.
- Submenu width (`320–360px`) may be wider than needed for short labels + counts.
- No clear selected/active state when a notification filter is already applied to the worklist.

### 3. No at-a-glance signal on the More actions trigger

Users cannot tell there are actionable queue items **before** opening the menu. The overflow trigger (`Icons.more_vert`) looks identical whether there are 0 or 20 pending notifications.

### 4. No aggregate count on the Notifications parent row

Individual notification rows show per-queue counts (`AppMenuCountBadge`), but the parent **Notifications** item does not summarize **total items needing attention**. Users must expand the submenu to discover volume.

### 5. Workspace header / toolbar uses too much vertical space

The OPD workspace header band (title + primary action + toolbar) has **excess top/bottom padding**, pushing the worklist down. The goal is maximum information density without crowding — compact but readable.

---

## Target UX

### A. Intelligent submenu positioning

Position nested menus **relative to available viewport space**, not a fixed offset that ignores layout.

| Viewport situation | Behavior |
|--------------------|----------|
| Room to the **right** of the parent menu (typical desktop) | Flyout opens **flush to the right edge** of the parent panel, vertically aligned with the **Notifications** row |
| Insufficient space on the right | Flip flyout to the **left** of the parent menu |
| Insufficient space below | Shift vertically so the submenu stays fully on-screen |
| Narrow (`xs` / `sm`) | Acceptable stacked pattern, but still **anchored to the trigger** — never centered in the page body |

**Rules:**

- Parent and child menus should **share a border edge** or overlap by 1px so they read as one control.
- Maximum gap between parent menu and flyout: **0–4 logical px** (theme `spacing.xs` or less).
- Do **not** let `crossAxisUnconstrained` or default `MenuAnchor` placement push the flyout into the worklist center.
- Prefer a shared helper (e.g. extend `_ToolbarOverflowMenu` or extract `AppToolbarNestedMenu`) so every workspace gets the same behavior.

**Primary files:** `frontend/lib/shared/layout/app_workspace_toolbar.dart` (`_ToolbarOverflowMenu`, `SubmenuButton`, `MenuAnchor`).

### B. Polished menu chrome

Apply existing design-system tokens — no ad-hoc colors or spacing in feature pages.

| Element | Spec |
|---------|------|
| Menu panel | `colorScheme.surface`, `outlineVariant` border, `theme.radius.sm` — match current `menuStyle` but tune width to content (`min` ~240, `max` ~320 unless labels require more) |
| Row height | Consistent `48` tap target; horizontal padding `theme.spacing.sm` |
| Icons | `AppMenuItemLabel` with tone-colored icons (reuse `workspaceStatusToneAccentColor`) |
| Trailing affordance | **Single** `Icons.chevron_right` on parent submenu rows — remove duplicate |
| Active filter | When a notification filter is active, show subtle selected background (`colorScheme.secondaryContainer` or existing menu selected state) on that submenu row |
| Hover / focus | Visible focus ring for keyboard users; pointer cursor on all interactive menu rows |

### C. More actions trigger — attention indicator

When `visibleWorkspaceSummaryNotifications` is non-empty, the **More actions** trigger must show a **visual pending indicator**:

| Option | When to use |
|--------|-------------|
| **Red dot** (small badge, top-right of icon button) | At least one notification with `count > 0` — preferred default |
| Dot only, no number on trigger | Keeps the ⋮ icon clean; counts live in the submenu |

**Rules:**

- Dot uses `theme.statusColors.error` or `colorScheme.error` — consistent with app notification badges (e.g. shell bell).
- Dot hidden when all notification counts are zero (same visibility rule as today).
- Accessible: `Semantics` / tooltip e.g. “More actions — N items need attention” (localized via `app_en.arb`).
- Reuse or extend `AppButton.popupMenuTrigger` rather than one-off decoration in each workspace.

### D. Notifications parent row — aggregate badge

On the **Notifications** submenu parent row, show a **total count badge** summing all visible notification `count` values:

```
[ bell icon ]  Notifications ……………………  [ 4 ]
                                      ▸
```

| Rule | Detail |
|------|--------|
| Total | `sum` of counts for all `visibleWorkspaceSummaryNotifications` |
| Format | `AppFormatters.compactNumber` (same as row badges) |
| Style | Reuse `AppMenuCountBadge` with neutral or `info` tone, **or** extract `AppMenuAggregateCountBadge` if styling differs from per-row badges |
| Zero | Parent row hidden entirely when total is 0 (existing behavior) |

### E. Compact workspace header / toolbar

Reduce wasted vertical space in `AppWorkspaceHeader` and related spacing **without** breaking touch targets on mobile.

| Area | Direction |
|------|-----------|
| `AppWorkspaceHeader` padding | Tighten `bottom` padding when `compact: true`; audit top padding inherited from `ResponsivePage` |
| Title row | Keep `compactHeader: true` default; ensure title + toolbar fit on one line on `md+` |
| Gap to filters/worklist | Use `ResponsiveSpacing.compactContentGapFor` — do not add extra `SizedBox` in feature pages |
| Toolbar action row | Preserve minimum 44–48px hit areas; reduce **margins** and **inter-row** gaps, not tap targets |

**Primary files:** `frontend/lib/shared/layout/app_workspace.dart` (`AppWorkspaceHeader`, `AppWorkspace`), `frontend/lib/shared/layout/responsive_spacing.dart`, `frontend/lib/shared/layout/responsive_page.dart`.

---

## Scope & constraints

- **Shared components only** — changes live in `app_workspace_toolbar.dart`, `app_workspace.dart`, `app_button.dart`, `app_menu_item_label.dart`, and shared badge helpers. Do **not** duplicate menu logic in individual `*_workspace_page.dart` files.
- **No behavior regression** — notification taps still apply the same worklist filters; zero-count rows still hidden.
- **Follow project rules:** `frontend/.cursor/ui-workspace.mdc`, `design-system.mdc`, `localization_i18n.mdc` (new strings in `app_en.arb`).
- **Uniform** — OPD, Lab, Billing, ICU, and all other workspaces using `appWorkspaceToolbarWithLabels` must look identical without per-module overrides.

---

## Acceptance criteria

1. Opening **More actions** on OPD shows a menu anchored to the ⋮ button in the header toolbar — not floating over the table center.
2. Hovering/expanding **Notifications** opens a flyout **immediately adjacent** to the parent menu (right or left based on space).
3. **Notifications** parent row has exactly **one** chevron and displays the **aggregate count** badge.
4. **More actions** ⋮ shows a **red dot** when any notification count > 0; dot disappears when all counts are zero.
5. Workspace header is **visibly shorter** than before on desktop while remaining usable on mobile.
6. Existing tests in `frontend/test/shared/layout/app_workspace_toolbar_test.dart` pass; add tests for dot visibility, aggregate badge, and submenu positioning where feasible.
7. Manual smoke on `127.0.0.1:5201` across OPD + two other modules confirms uniform appearance.

---

## Out of scope (this pass)

- Changing what each notification count represents or filter logic in module controllers.
- Reintroducing inline summary card grids.
- Shell-level notification bell (`responsive_shell_scaffold.dart`) — only workspace toolbar More actions is in scope.
