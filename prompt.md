# Global uppercase modal dialog titles

## Goal
Every modal dialog header title should render in **UPPERCASE** so titles are visually distinct and consistent app-wide.

## Approach
Enforce formatting **once at the shared component layer**. Call sites must not be updated individually.

Primary files:
- `frontend/lib/shared/components/app_dialog.dart` — header renders `title` via `normalizeDialogTitleWidget`
- `frontend/lib/core/utils/app_title_case.dart` — title normalization helper (update or replace as needed)
- `frontend/lib/shared/components/app_dialog.dart` — `showAppDialog` entry point

## Requirements
1. Plain `Text` and simple single-span `TextSpan` titles passed to `AppDialog.title` display in uppercase.
2. Non-text or complex custom title widgets are left unchanged.
3. Only the dialog **header title** is affected—not action buttons, field labels, or body content.
4. If other shared modal wrappers bypass `AppDialog`, extend the same normalization there or route them through `AppDialog`.

## Out of scope
- Manually uppercasing strings at individual dialog call sites
- Changing dialog layout, typography weight, or colors unless required for readability

## Acceptance criteria
- [ ] Any dialog opened via `showAppDialog` / `AppDialog` shows an uppercase header title
- [ ] Unit tests cover the normalization helper (including empty titles and custom widgets)
- [ ] Existing `app_dialog_test.dart` passes
