# Global workspace toolbar & overflow menu polish

Apply this **app-wide** to every screen that uses `AppWorkspace`, `AppWorkspaceToolbar`, or the shell header actions. The issues below appear on multiple modules (OPD, Billing, Lab, etc.); fix the shared components once rather than per screen.

---

## Goal

Unify all workspace header actions into a **ghost / text action** style (icon + label only, no filled background, no outline border) that reads cleanly on every theme and header color. Replace the current **More actions** bottom sheet with a **dropdown popup** styled like the user profile menu.

---

## Problems to fix

1. **Toolbar actions look like bordered buttons** — Screen-specific actions, Refresh, Report fault, Request maintenance, and the More (`more_vert`) trigger render as `AppButton.secondary` / `OutlinedButton` (visible border + hover fill). They should look like lightweight icon+label controls, not boxed buttons.
2. **More actions opens a bottom sheet** — `_ToolbarOverflowMenu` in `app_workspace_toolbar.dart` uses `showModalBottomSheet`, so the menu is pushed to the bottom of the screen. It should anchor under the More button like `_UserMenuButton` (`PopupMenuButton`, `PopupMenuPosition.under`).
3. **Overflow items render as full buttons** — `_OverflowActionRow` embeds the original toolbar widgets inside the sheet, so overflow entries still appear as bordered buttons. They should be **list rows**: leading icon, label text, row hover/focus, same tap behavior as the inline action.
4. **Fullscreen toggle still shows a labeled bordered button on wide breakpoints** — `AppFullscreenToggle` switches to `AppButton.secondary` when not on xs/sm. It should stay **icon-only** (no label, no border, no background) at all breakpoints, matching the desired shell action style.
5. **Inconsistent styling vs user menu** — The user profile dropdown (`responsive_shell_scaffold.dart` → `_UserMenuButton`, `_UserMenuItemLabel`) is the visual reference. Overflow menu items must match that list-item pattern.

---

## Visual spec — ghost toolbar actions

Create or reuse a single shared style for **toolbar/header actions** (not primary page CTAs):

| Property | Requirement |
|----------|-------------|
| Background | Always transparent (default, hover, pressed) |
| Border | None |
| Content | Leading icon + label when `AppActionLabelScope.showLabels == true`; icon-only when `forceIconOnly == true` |
| Colors | Use `colorScheme.onSurfaceVariant` (or existing token) so actions work on light, dark, and tinted headers |
| Hover / focus / pressed | Subtle overlay only (reuse `AppIconButton` overlay alphas or equivalent) — no box fill |
| Typography | `theme.textTheme.labelLarge`, semibold if that matches existing shell actions |
| Spacing | Compact; preserve minimum tap target (`appTokens.minInteractiveDimension`) |

**Applies to:** `AppIconButton` when used inside `AppActionLabelScope` with labels, global actions (`AppWorkspaceRefreshAction`, `AppGlobalFaultReportAction`, `AppGlobalHousekeepingRequestAction`), screen-specific toolbar widgets passed via `AppWorkspaceToolbarConfig.primary` / `.secondary`, and the More trigger.

**Does not change:** Primary filled CTAs (`AppButton.primary`) used for the main screen action (e.g. “Post payment”, “Start walk-in”) unless a screen incorrectly uses secondary for its primary CTA.

---

## Layout rules — inline vs overflow

Keep existing responsive budget logic in `AppWorkspaceToolbar`, but ensure behavior is:

1. **Up to 3 screen-specific actions** (`secondary` + `primary`, in that order) stay **inline** first (`maxVisibleScreenActions`, default 3).
2. **Global actions** (Refresh, fault report, housekeeping) sit inline when width allows; overflow to More when narrow (existing `_resolveLayout` behavior).
3. **More button** (`Icons.more_vert`) appears when any action overflows; it uses the same ghost icon-only style (no border/background).
4. Width estimation constants in `_AdaptiveToolbarLayout` may need updating after ghost actions shrink — verify no header overflow at **1280×800** and on **360px** widths.

---

## Overflow / More menu spec

Replace `_ToolbarOverflowMenu` bottom sheet with a anchored popup:

| Property | Requirement |
|----------|-------------|
| Widget | `PopupMenuButton` (or shared wrapper), `position: PopupMenuPosition.under` |
| Panel | Same surface treatment as user menu: `colorScheme.surface`, outline border via `RoundedRectangleBorder`, sensible min/max width (~320–360) |
| Items | One `PopupMenuItem` (or custom entry) per overflow action — **not** embedded `AppButton` widgets |
| Row layout | Extract or share `_UserMenuItemLabel` pattern: fixed-width icon slot + label (`Row`, icon `onSurfaceVariant`, ellipsized text) |
| Interaction | Selecting a row runs the action’s `onPressed` / callback; disabled actions respect `enabled` state |
| Metadata | Each overflow entry must expose **icon + label** even if the inline widget was icon-only — add a small adapter or action descriptor if needed |
| Mobile | On xs/sm, popup-under is still preferred over bottom sheet; only use bottom sheet if popup genuinely cannot fit (avoid unless necessary) |

Refactor `_OverflowActionRow` away; overflow rendering should not reuse bordered toolbar widgets.

---

## Fullscreen toggle

In `app_fullscreen_toggle.dart`:

- Always render `AppIconButton` (icon-only) at **all** breakpoints.
- Remove the `AppButton.secondary` branch for md+ widths.
- No label, no border, no background.

---

## Files to touch (starting points)

| File | Change |
|------|--------|
| `frontend/lib/shared/components/app_icon_button.dart` | Labeled mode: ghost row instead of `AppButton.secondary` |
| `frontend/lib/shared/components/app_button.dart` | Optional: add `AppButton.ghost` / toolbar variant if cleaner than special-casing `AppIconButton` |
| `frontend/lib/shared/layout/app_workspace_toolbar.dart` | Popup overflow menu; list-item rows; width estimates |
| `frontend/lib/shared/layout/app_fullscreen_toggle.dart` | Icon-only at all breakpoints |
| `frontend/lib/shared/layout/responsive_shell_scaffold.dart` | Consider extracting `_UserMenuItemLabel` to a shared component reused by overflow menu |
| `frontend/lib/shared/actions/*.dart` | Ensure global actions work with new ghost + overflow metadata |
| `frontend/test/shared/layout/app_workspace_toolbar_test.dart` | Update/add tests for popup menu, ghost styling, layout |

Audit workspace pages only if they pass custom toolbar widgets that bypass shared components.

---

## Acceptance criteria

- [ ] Every workspace screen: inline toolbar actions show **icon + label** (or icon-only on xs/sm) with **no visible border or button background** on default state.
- [ ] Refresh, Report fault, Request maintenance, More, and Fullscreen match the same ghost action family.
- [ ] Fullscreen is **icon-only on all breakpoints**.
- [ ] Tapping More opens a **dropdown under the button**, not a bottom sheet, on desktop and typical mobile widths.
- [ ] Each overflow item is a **list row** (icon left, label right) with hover/focus feedback — visually aligned with the user profile menu.
- [ ] Overflow items retain full functionality (refresh, dialogs, navigation, etc.).
- [ ] First **3 screen-specific** actions remain inline; additional screen actions appear only in More.
- [ ] No `RenderFlex overflow` at 1280×800 with a busy toolbar (billing-style: primary + 2 secondary + globals).
- [ ] Looks correct in **light and dark** themes and on **tinted workspace headers**.
- [ ] Widget tests in `app_workspace_toolbar_test.dart` pass; add coverage for popup overflow and ghost labeled actions.

---

## Out of scope

- Changing primary CTA styling (`AppButton.primary` filled buttons for main screen actions).
- Reworking board/view toggles unless they also show unwanted borders (leave as-is unless visibly broken).
- Per-module toolbar one-offs — fix shared layout/components instead.

---

## Verification

1. Run `flutter test frontend/test/shared/layout/app_workspace_toolbar_test.dart`.
2. Manually spot-check at least 3 modules with different toolbar densities (e.g. OPD, Billing, Lab) at 1280×800 and 360×640.
3. Confirm More menu and user profile menu look like the same design system.
