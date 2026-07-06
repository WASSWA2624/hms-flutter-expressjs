# Task: Theme-based viewport margins for maximized `AppDialog`

## Goal

When any `AppDialog` is **maximized**, it should expand to the largest practical size but **not** cover the entire viewport. Leave a visible margin on the **left, right, and bottom** so the underlying UI remains perceptible and users can tell the surface is a dialog layered above the app—not a full-screen view.

This behavior must apply **at every screen size** (mobile, tablet, desktop). All margin values must come from a **single centralized theme definition**—no hard-coded pixel literals or viewport-specific magic numbers in `AppDialog`.

## Scope

| Area | Files |
| --- | --- |
| Theme tokens (primary) | `frontend/lib/app/theme/app_theme_extensions.dart`, `frontend/lib/app/theme/app_theme.dart` |
| Dialog implementation | `frontend/lib/shared/components/app_dialog.dart` |
| Tests | `frontend/test/shared/components/app_dialog_test.dart` (+ theme extension tests if added) |

**Out of scope:** Other dialog wrappers, routing, or unrelated UI changes.

## Current behavior

When `_isMaximized` is `true`:

- `insetPadding` is `EdgeInsets.zero`
- Shell size is `Size(viewport.width, viewport.height)`
- `_dragOffset` is reset to `Offset.zero`

The dialog fills the full viewport on all breakpoints. Inset and clearance values (`_snackBarClearance`, compact vs desktop spacing in `_dialogInsetPadding`) are defined locally in `app_dialog.dart`.

## Desired behavior

### 1. Centralized theme definition

Add dialog inset tokens to the theme layer (prefer **`AppDesignTokens`** in `app_theme_extensions.dart`, which already holds responsive layout values like `pagePaddingMobile` / `pagePaddingTablet` / `pagePaddingDesktop`).

Define tokens for:

- **Normal dialog inset** — margins when the dialog is not maximized (replace inline logic in `_dialogInsetPadding`).
- **Maximized dialog inset** — margins when maximized (left, right, bottom; top may be flush or use the normal top inset—match existing non-maximized conventions).
- **Snack-bar clearance** — bottom offset so dialogs do not overlap snackbars (replace `_snackBarClearance`).

Each token set should be **responsive** (e.g. mobile / tablet / desktop variants) and registered in `AppTheme` via `ThemeExtension`. Expose via the existing `ThemeData` extension getters (`theme.design`, `theme.spacing`, etc.).

`AppDialog` must **only consume** these tokens—no local `const` margin values.

### 2. All screen sizes

- Maximized inset rules apply on **every** viewport width and height, including compact (< 600 px) layouts.
- Where maximize is currently disabled (e.g. no maximize button on compact), still apply the inset model anywhere `initialMaximized` or programmatic maximize is used.
- Responsive token selection (mobile vs tablet vs desktop) should follow the same breakpoint strategy used elsewhere in the app theme—not ad-hoc width checks with hard-coded thresholds inside `AppDialog` unless the breakpoint itself is a named theme constant.

### 3. Dialog behavior (unchanged semantics)

- **Restore** — Maximize ↔ restore must preserve pre-maximize size and drag offset (`_preMaximizeSize` / `_preMaximizeDragOffset`).
- **Resize / drag** — Maximized dialogs stay non-resizable and non-draggable; resizing while maximized exits maximize mode as today.
- **`initialMaximized`** — Same inset rules on first paint.

### 4. Single source of truth

- One theme helper (e.g. `EdgeInsets dialogInsetPadding(ThemeData theme, Size viewport, {required bool maximized})`) used by `build`, `_toggleMaximize`, resize, and drag bounds so calculations never diverge.

## Acceptance criteria

- [ ] New dialog inset tokens live in `app_theme_extensions.dart` and are wired in `app_theme.dart`.
- [ ] `AppDialog` has no hard-coded margin, clearance, or inset pixel values for normal or maximized states.
- [ ] Maximized dialog never equals full viewport width or height on **any** tested viewport size.
- [ ] Left, right, and bottom margins are visible and derive from theme tokens at mobile, tablet, and desktop sizes.
- [ ] Background/scrim and content behind the dialog remain partially visible at the margins.
- [ ] Maximize ↔ restore preserves pre-maximize dimensions and position.
- [ ] Tests updated: assert inset-based dimensions (not full viewport) at multiple sizes; add or extend theme token tests if new extensions are introduced.
- [ ] `flutter test test/shared/components/app_dialog_test.dart` passes.

## Implementation hints

- Model maximized insets after existing responsive patterns (`pagePaddingMobile` / `pagePaddingTablet` / `pagePaddingDesktop`).
- Apply insets via `Dialog.insetPadding` and/or reduced shell dimensions—whichever keeps layout, constraints, and drag bounds correct.
- Do not change maximize button labels, icons, or accessibility strings unless required by the new layout.
