# Task: Fix AppDialog resize and maximize behavior

## Goal

Make desktop `AppDialog` windows behave like a resizable, maximizable panel: users can drag to any reasonable width and height, and the maximize/restore control should fill the entire usable viewport in both dimensions.

## Context

`AppDialog` is the shared modal shell used across workspace pages (HR staff detail, filters, forms, etc.). It is opened via `showAppDialog` and supports header drag, edge/corner resize handles, and a maximize/restore header button on desktop (`viewport.width >= 600`).

Example usage (HR staff detail):

- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — `_openSelectedStaffDialog` opens an `AppDialog` with `scrollable: true`, `maxWidth: 980`.

Implementation lives in:

- `frontend/lib/shared/components/app_dialog.dart` — sizing state (`_desktopSize`, `_isMaximized`), resize handles, maximize toggle, inset padding, and drag offset.

Existing widget tests cover header drag, maximize toggle, and corner resize in `frontend/test/shared/components/app_dialog_test.dart`.

## Problem

Observed on desktop (e.g. HR → Staff detail dialog at `127.0.0.1:5201/hr`):

1. **Manual resize is unreliable** — vertical and horizontal resizing do not consistently produce the size the user drags to. Before the first explicit resize, height is content-driven (`_desktopSize == null`), which limits vertical resize. Edge handles may not reflect the final shell dimensions the user expects.
2. **Maximize does not fill the viewport** — clicking the maximize button (fullscreen icon in the header) enlarges the dialog but leaves visible margins; it does not occupy the full available width and height. Restore should return to the pre-maximize size and position.

These issues reduce usability for detail-heavy dialogs where users need more space to read overview fields, actions, and record sections.

## Requirements

### 1. Bidirectional manual resize

- On desktop, when `resizable: true` (default), users must be able to resize **both width and height** independently via the right edge, bottom edge, and bottom-right corner handles.
- Dragging a handle should update the dialog shell to match the drag delta, clamped only by sensible min/max bounds (current mins: 360×280; max = viewport minus non-maximized inset padding).
- Resizing from any handle should establish an explicit shell size so subsequent drags behave predictably (no “content-only height” after the user has started resizing).
- Dragging while maximized should exit maximize mode and continue resizing from the restored shell size (existing behavior; preserve or improve).
- Header drag and close/maximize controls must keep working after resize.

### 2. True viewport maximize

- When the user clicks **Maximize**, the dialog must expand to fill the **full usable viewport** horizontally and vertically:
  - `insetPadding: EdgeInsets.zero` (already set when maximized).
  - Shell width and height must equal `MediaQuery.sizeOf(context)` (or equivalent), with no leftover margin from stale inset calculations or `maxWidth` caps.
- Content area should grow with the shell (`fillHeight` / scrollable content should use the extra space).
- **Restore** must return to the exact pre-maximize size and drag offset (existing `_preMaximizeSize` / `_preMaximizeDragOffset` intent).
- Maximize/restore icon and tooltip behavior unchanged (`Icons.fullscreen` / `Icons.fullscreen_exit`).

### 3. Consistent sizing model

- Resolve any mismatch between:
  - constraints computed in `build` when `_isMaximized`,
  - sizes stored in `_toggleMaximize`,
  - and `_measuredShellSize` fallback when `_desktopSize` is null.
- Prefer one source of truth for “available viewport” vs “inset viewport” so maximize and resize clamp to the same bounds.

### 4. Mobile unchanged

- Viewports `< 600` wide keep current full-width, non-resizable, non-maximizable behavior.

## Out of scope

- Redesigning dialog visual style (header, borders, action footer).
- Adding new dialog features (minimize, multi-window, persistence of size across sessions).
- Changing `showAppDialog` API or call sites unless required for sizing fixes.
- Shell sidebar / app bar layout changes.

## Key files

- `frontend/lib/shared/components/app_dialog.dart` — primary fix
- `frontend/test/shared/components/app_dialog_test.dart` — extend coverage
- `frontend/lib/features/hr/presentation/pages/hr_workspace_page.dart` — manual QA reference

## Acceptance criteria

- [ ] On desktop, dragging right, bottom, and corner handles resizes width and height smoothly to user-chosen dimensions within min/max bounds.
- [ ] After maximize, dialog shell width and height match the viewport (no visible gap around the dialog surface).
- [ ] Restore returns to prior size and position within tolerance used by existing tests.
- [ ] HR Staff detail dialog (`maxWidth: 980`, `scrollable: true`) can be manually enlarged and fully maximized.
- [ ] Mobile layout behavior unchanged.
- [ ] Widget tests updated or added for: full-viewport maximize dimensions, independent horizontal/vertical edge resize, and restore after maximize.
- [ ] `flutter analyze` and `app_dialog_test.dart` pass.

## Suggested approach

1. Trace sizing in `_AppDialogState.build`, `_toggleMaximize`, and `_handleResize`; identify where inset padding or `maxWidth` prevents full viewport fill when maximized.
2. Ensure first resize seeds `_desktopSize` from `_measuredShellSize` so vertical resize works even when initial height was intrinsic.
3. When maximized, set shell dimensions directly from viewport size; avoid reusing inset-subtracted `availableWidth`/`availableHeight` for stored `_desktopSize`.
4. Add/adjust tests with a fixed viewport (e.g. 1000×700) asserting maximized shell equals viewport and edge drags change only the intended axis.
5. Manually verify on web at `.\tool\run_web_5201.ps1` → HR → open any staff detail → resize edges/corner → maximize → restore.

## Deliverable

A focused change to `AppDialog` sizing logic with test coverage, restoring predictable resize and true viewport maximize on desktop dialogs.
