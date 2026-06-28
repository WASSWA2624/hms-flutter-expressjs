# Workspace Header / Toolbar — Small-Screen Layout Fix

## Objective

Fix responsive layout bugs in the **module workspace header** (screen title + action toolbar area below the global app menu bar) so it stays compact, aligned, and readable on narrow viewports. The screen label must **always remain visible**; secondary actions should collapse into a single overflow control instead of wrapping into extra rows.

**Reference screenshots** (reproduce at `127.0.0.1:5201/lab` in responsive mode):

| Width | File |
|-------|------|
| Desktop (~full) | `assets/.../image-b0f1d95c-19d4-4bf3-bfa3-5d258b4bf7c8.png` |
| 759px | `assets/.../image-ad1ba468-0b37-4269-8a18-46bce0a1389d.png` |
| 626px | `assets/.../image-b6432cba-4d04-4b23-a8ea-906a9223fbbe.png` |
| 426px | `assets/.../image-867050d0-e894-46fd-a2ee-ceff92ea1e2d.png` |
| 258px | `assets/.../image-bee33dda-09ca-4c02-98e0-fd3fb39df050.png` |

---

## Problem summary (current behavior)

Observed on the Laboratory workspace (`lab_workspace_page.dart`) but caused by **shared layout components** — the fix must apply to every `AppWorkspace` screen, not just Lab.

1. **Screen title disappears on `xs`.** `AppWorkspaceHeader` sets `hideTitle: breakpoint == AppBreakpoint.xs`, leaving only the module icon (flask) with no text at ~258px (see last screenshot).
2. **Header stacks into 2–3 rows on small/medium widths.** `AppWorkspaceHeader` uses a `Wrap` when `breakpoint == xs` or `constraints.maxWidth < AppBreakpoints.md`, placing the title block on one row and the toolbar on the next (626px screenshot shows title + “Live sync” on row 1, actions on row 2, overflow on row 3).
3. **“Live sync” status badge wastes horizontal space.** The `AppWorkspaceStatus` badge (e.g. `AppWorkspaceLiveStatus.fromSavingState`) competes with the title and actions; the product decision is to **remove it from the header entirely**.
4. **Vertical misalignment.** At the narrowest width, the leading icon and the overflow (⋮) button sit on different baselines.
5. **Excessive vertical chrome.** Stacked header rows consume ~25–30% of viewport height on mobile, leaving little room for content.

---

## Target UX (all breakpoints)

### Single-row header layout

Always render **one horizontal row**:

```
[ module icon ] [ screen title (ellipsis) ]  ···spacer···  [ inline actions (if room) ] [ ⋮ More actions ]
```

| Element | Rule |
|---------|------|
| Module icon | Always visible (`AppWorkspaceTitleIcon` / `leading`). |
| Screen title | **Never hidden.** Truncate with `TextOverflow.ellipsis` (1 line). Use `Expanded`/`Flexible` so it yields space to actions. |
| Live sync / saving status | **Remove from header.** Do not render `AppWorkspaceStatus` in `AppWorkspaceHeader` at any breakpoint. Saving/refresh feedback may remain in toolbar refresh action or elsewhere — not as a persistent header badge. |
| Screen actions | Show inline only when width allows; otherwise move **all** screen actions into the overflow menu. |
| Overflow (⋮) | Always reachable on `xs`/`sm`; vertically centered with icon + title. |

### Breakpoint behavior

| Breakpoint | Title | Actions |
|------------|-------|---------|
| `lg`+ | Full title + inline labeled actions (current desktop behavior) | |
| `md` | Title + as many inline actions as fit | Remainder → overflow |
| `sm` / `xs` | Title always visible (may ellipsize) | Icon-only inline if room; otherwise all actions in overflow |

**Do not** stack title and toolbar into separate full-width rows via `Wrap`.

---

## Scope

### In scope

| Area | Location |
|------|----------|
| Workspace header layout | `frontend/lib/shared/layout/app_workspace.dart` — `AppWorkspaceHeader`, `_WorkspaceHeaderTitle`, `_WorkspaceHeaderText` |
| Toolbar overflow / single-row actions | `frontend/lib/shared/layout/app_workspace_toolbar.dart`, `app_toolbar_overflow_resolver.dart` |
| Live status helper (stop using in header) | `frontend/lib/shared/layout/app_workspace_live_status.dart` |
| All `AppWorkspace` call sites that pass `status:` | e.g. `lab_workspace_page.dart`, `pharmacy_workspace_page.dart`, `ipd_workspace_page.dart`, etc. |

### Out of scope

- Global app menu bar (`responsive_shell_scaffold.dart` / `AppMenuBar`) — separate concern unless header fix requires shared spacing tokens.
- Page body content (summary cards, tables, search bar) — only fix header/toolbar unless a trivial spacing adjustment is needed directly below the header.
- Removing l10n strings for “Live sync” — strings may remain for other uses; just stop rendering the badge in the workspace header.

---

## Implementation strategy

Work in this order. Prefer shared-component fixes so all workspaces inherit behavior.

### Phase 1 — `AppWorkspaceHeader` single-row layout

1. **Remove `hideTitle` / `hideStatus` logic** for `AppBreakpoint.xs`. The title must render at every breakpoint.
2. **Stop rendering `status` in the header.** Remove the `status` parameter from the header UI (or ignore it in `AppWorkspaceHeader` / `_WorkspaceHeaderTitle`). Update `AppWorkspace` to not pass status into the header widget tree.
3. **Replace `Wrap` stacking** with a single `Row`:
   - `leading` icon (fixed width)
   - `Expanded` title `Text` (ellipsis, `maxLines: 1`)
   - `Flexible` / intrinsic toolbar cluster aligned `centerRight`
4. **Vertically center** all row children (`crossAxisAlignment: CrossAxisAlignment.center`). Ensure icon, title, and overflow button share the same height baseline.
5. **Delete or simplify** `_WorkspaceHeaderText` narrow `Column` layout that placed title above status — no longer needed once status is removed.

### Phase 2 — Toolbar cooperation on narrow widths

1. In `AppWorkspaceToolbar`, when `showLabels` is false (`xs`/`sm`), ensure the overflow menu receives **all** screen actions (already partially implemented via `_resolveLayout` when `!showLabels`) and that the overflow button is always shown when any actions exist.
2. Verify `_AdaptiveToolbarLayout` does not force a second row inside the header area. The toolbar widget should report a single intrinsic height.
3. Title block and toolbar must negotiate width in one `Row` — title `Expanded`, toolbar `Flexible(fit: FlexFit.loose)` with `ClipRect` + right alignment.

### Phase 3 — Call-site cleanup

1. Remove `status: AppWorkspaceLiveStatus.fromSavingState(...)` (and equivalent) from all `AppWorkspace(...)` usages, or leave the parameter deprecated/unused if removing the API is too broad — **header must not display it**.
2. Confirm `onRefresh` / `isRefreshing` on `AppWorkspaceToolbarConfig` still provides refresh feedback without the live-sync badge.

### Phase 4 — Regression pass

Manually verify at **258px, 426px, 626px, 759px, and desktop** on at least:

- Laboratory (`/lab`) — screenshots reference case
- One additional module with multiple toolbar actions (e.g. Pharmacy or OPD)

---

## Acceptance criteria

- [ ] Screen title text is visible at **every** breakpoint, including `xs` (~258px). It ellipsizes rather than disappearing.
- [ ] Workspace header is **one row** at all widths — no stacked title/toolbar rows.
- [ ] **No “Live sync” / saving status badge** in the workspace header on any screen.
- [ ] Module icon, title, and overflow (⋮) button are **vertically aligned** on narrow screens.
- [ ] On `xs`/`sm`, screen actions are reachable via overflow; semantics and tooltips preserved.
- [ ] Desktop (`lg`+) layout unchanged or improved — inline labeled actions still work.
- [ ] No new `RenderFlex overflow` warnings at tested widths.
- [ ] `dart analyze` passes on touched files; existing layout/widget tests updated if they assert on hidden titles or status badges.

---

## Verification

1. **Automated:** run frontend tests touching `app_workspace` / toolbar (`frontend/test/`).
2. **Manual:** resize browser at `/lab` to 258, 426, 626, 759px and full width; compare against reference screenshots — header should be a single compact row with visible “Laboratory” title.
3. **Spot-check** 2–3 other `AppWorkspace` modules for consistent header behavior.

---

## Constraints

- **Minimize diff scope** — fix shared layout components first; avoid per-page layout overrides.
- **Preserve behavior** — action callbacks, overflow menu items, refresh, and accessibility labels must remain intact.
- **Follow existing conventions** — use `AppBreakpoints`, `theme.spacing.*`, `AppButton`, `AppWorkspaceToolbarConfig`, and `AppActionLabelScope` patterns already in the codebase.
- **No new dependencies.**
