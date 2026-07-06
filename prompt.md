# Task: Uniform, tighter maximized dialog margins

## Goal

Refine **maximized** `AppDialog` viewport margins so all four sides are **equal** and **slightly tighter** than today. The dialog should still read as a layer above the workspace (background visible on every edge), but use space more efficiently.

**Visual reference:** Patient profile dialog (e.g. SAMUEL DEMO-BRAVO on `/patients`) in maximized mode. Top/left/right gaps are acceptable but a bit large; the **bottom gap is noticeably larger** than the other sides and should match them.

## Problem

In `AppDialogInsets.paddingFor`, maximized bottom inset is `horizontalInset + dialogSnackBarClearance` (88 px), while top/left/right use only `horizontalInset`. On desktop this yields ~24 px sides/top vs ~112 px bottom — uneven and wasteful.

Current maximized tokens (`AppDesignTokens.standard`):

| Breakpoint | Token | Value |
| --- | --- | --- |
| xs, sm | `dialogMaximizedInsetMobile` | 8 |
| md, lg | `dialogMaximizedInsetTablet` | 16 |
| xl, xxl | `dialogMaximizedInsetDesktop` | 24 |

## Desired behavior

1. **Uniform maximized insets** — Top, left, right, and bottom use the **same** theme token value. Do **not** add `dialogSnackBarClearance` to maximized bottom inset (reserve snack-bar clearance for non-maximized dialogs only).
2. **Slightly tighter** — Reduce maximized inset tokens a step below current horizontal/top values (e.g. desktop 24 → 16). Tune mobile/tablet proportionally; margins should feel balanced—not cramped, not oversized.
3. **Theme-only** — Adjust values in `AppDesignTokens` (`app_theme_extensions.dart`); no hard-coded pixel literals in `AppDialog` or `AppDialogInsets`.
4. **All screen sizes** — Responsive maximized insets via existing `AppBreakpoint` mapping in `app_dialog_insets.dart`.
5. **Unchanged semantics** — Maximize ↔ restore, resize, drag, and `initialMaximized` behavior stay as implemented.

## Scope

| Area | Files |
| --- | --- |
| Inset logic | `frontend/lib/shared/layout/app_dialog_insets.dart` |
| Theme tokens | `frontend/lib/app/theme/app_theme_extensions.dart` |
| Tests | `frontend/test/shared/layout/app_dialog_insets_test.dart`, `frontend/test/shared/components/app_dialog_test.dart`, `frontend/test/app/theme/app_theme_test.dart` |

## Acceptance criteria

- [ ] Maximized dialog margins are **visually equal** on top, left, right, and bottom (verify on patient profile dialog at desktop width).
- [ ] Bottom margin is **no longer larger** than the other sides.
- [ ] Margins are **slightly smaller** than the current top/horizontal maximized inset (~24 px desktop).
- [ ] Underlying workspace remains visible on all edges.
- [ ] Non-maximized dialogs still apply `dialogSnackBarClearance` on the bottom.
- [ ] All values come from `AppDesignTokens`; no new magic numbers in components.
- [ ] Updated tests pass: `flutter test test/shared/components/app_dialog_test.dart test/shared/layout/app_dialog_insets_test.dart test/app/theme/app_theme_test.dart`.

## Implementation hints

- In `paddingFor`, branch on `maximized`: when `true`, return symmetric `EdgeInsets.all(inset)`; when `false`, keep existing bottom clearance logic.
- Suggested starting values: mobile `6`, tablet `12`, desktop `16` — adjust if needed after visual check.
