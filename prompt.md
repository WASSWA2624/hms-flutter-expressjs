# Task: Add viewport margins to maximized `AppDialog`

## Goal

When a desktop dialog is **maximized**, it should expand to the largest practical size but **not** cover the entire viewport. Leave a visible margin on the **left, right, and bottom** so the underlying UI remains perceptible and users can tell the surface is a dialog layered above the app—not a full-screen view.

## Scope

- **File:** `frontend/lib/shared/components/app_dialog.dart`
- **Component:** `AppDialog` (desktop / non-compact viewports only; compact/mobile behavior unchanged)
- **Out of scope:** Other dialog wrappers, routing, or unrelated UI changes

## Current behavior

When `_isMaximized` is `true`:

- `insetPadding` is `EdgeInsets.zero`
- Shell size is `Size(viewport.width, viewport.height)`
- `_dragOffset` is reset to `Offset.zero`

The dialog therefore fills the full viewport.

## Desired behavior

1. **Maximized size** — Use the viewport minus consistent margins on left, right, and bottom. Top may remain flush (or use the same inset as the non-maximized top inset—pick whichever matches existing layout conventions).
2. **Reuse existing spacing** — Prefer `theme.spacing` values already used in `_dialogInsetPadding` (e.g. `xl` on desktop) rather than hard-coded pixel literals. Keep `_snackBarClearance` in mind for the bottom margin if snackbars overlay the workspace.
3. **Positioning** — Center or align the maximized dialog within the available area; reset drag offset appropriately so the shell sits in the inset frame.
4. **Restore** — Toggling maximize off must still restore the pre-maximize size and drag offset (existing `_preMaximizeSize` / `_preMaximizeDragOffset` behavior).
5. **Resize / drag** — Maximized dialogs remain non-resizable and non-draggable (current behavior). Resizing while maximized should still exit maximize mode as today.
6. **`initialMaximized`** — Apply the same inset rules when the dialog opens already maximized.

## Acceptance criteria

- [ ] Maximized dialog does **not** equal full viewport width or height on desktop (≥ 600 px wide).
- [ ] Left, right, and bottom margins are visibly consistent and use theme spacing.
- [ ] Background/scrim and content behind the dialog remain partially visible at the margins.
- [ ] Maximize ↔ restore toggle preserves pre-maximize dimensions and position.
- [ ] Compact viewports (< 600 px) are unaffected.
- [ ] Update `frontend/test/shared/components/app_dialog_test.dart` (`desktop maximize toggles shell size and icon`) to assert inset dimensions instead of full viewport size.
- [ ] `flutter test test/shared/components/app_dialog_test.dart` passes.

## Implementation hints

- Centralize maximized inset logic (e.g. a helper or shared `EdgeInsets`) so `build`, `_toggleMaximize`, and any size calculations stay in sync.
- Apply insets via `Dialog.insetPadding` and/or reduced `shellWidth` / `shellHeight`—whichever keeps layout, constraints, and drag bounds correct.
- Do not change maximize button labels, icons, or accessibility strings unless required by the new layout.
