# Duplicate review action layout and choice previews

## Context

Patient registry **Duplicate review** opens `PatientDuplicateReviewDialog`. Each candidate card currently shows **Review merge** and **Dismiss** left-aligned under the pair summary. After **Review merge**, `PatientDuplicateMergeWorkspace` shows field lanes plus a left-aligned wrap of **Keep left**, **Keep right**, and **Auto-merge**; selecting one reveals a banner and **Merge patients**.

This prompt only adjusts action placement and adds a compact survivor preview for each merge choice. Do not change scoring, dismiss persistence, merge APIs, or registration-time similarity.

Follow [dialogs.mdc](/.cursor/dialogs.mdc), [theming.mdc](/.cursor/theming.mdc), [localization.mdc](/.cursor/localization.mdc), [responsiveness.mdc](/.cursor/responsiveness.mdc), and [prompt.mdc](/.cursor/prompt.mdc). Do not restate those files.

### Terms

- **Pair card:** one duplicate candidate block with score, classification, patient pair, match reasons, and card actions.
- **Merge workspace:** the field-level merge section opened by **Review merge**.
- **Choice preview:** a short read-only summary of the identity/demographics that would be kept if that merge choice is confirmed (before the user presses **Merge patients**).
- **Choice row:** the Keep left / Auto-merge / Keep right control row under the merge workspace field lanes.

## Requirements

1. **Right-align pair-card actions.** On each duplicate pair card, place **Review merge** and **Dismiss** on the trailing/right side of the card action area (same order: Review merge, then Dismiss). Keep existing RBAC gates and enabled/busy rules.

2. **Reposition merge choice actions.** In the merge workspace choice row, lay out actions as:
   1. **Keep left** — start / left
   2. **Auto-merge** — center
   3. **Keep right** — end / extreme right  
   Use a single horizontal row on wide layouts (`SpaceBetween` / equivalent). On narrow widths, keep the same visual order (left → auto → right) without stacking in a confusing order; prefer wrapping with left/auto/right still reading L→C→R.

3. **Show a choice preview before each merge action.** Immediately above (or tightly paired with) each of Keep left, Auto-merge, and Keep right, show a compact preview of the values that choice would preserve as the survivor profile (at least name, and other non-empty summary fields such as DOB, gender, phone/email when present). Previews must reflect the **current** field-lane values after any swaps. Empty fields stay visible as empty placeholders, not omitted silently.

4. **Keep confirm step.** Selecting Keep left / Keep right / Auto-merge still only selects the resolution; **Merge patients** remains the explicit confirm. Previews update when the selection changes and when field values are swapped. Unauthorized merge/dismiss controls must not render.

5. **Preserve states.** Loading, error, busy/disabled while saving, empty queue, and success snackbars stay as today. Do not regress dismiss or merge success/failure behavior.

## Constraints

- Edit `PatientDuplicateReviewDialog` / `_DuplicateReviewCard` and `PatientDuplicateMergeWorkspace` only for this layout/preview work.
- Reuse shared buttons, banners, badges, and panels; do not invent a second merge flow.
- No backend, repository, or unrelated registry refactors.
- Add l10n only for new preview labels if needed; reuse existing action labels.

## Acceptance Criteria

1. With a duplicate candidate visible, **Review merge** and **Dismiss** appear right-aligned on the pair card.
2. After **Review merge**, the choice row shows **Keep left** (left), **Auto-merge** (center), **Keep right** (right).
3. Each choice has a preview of the values that choice would keep; swapping a field updates those previews before confirm.
4. **Merge patients** still appears only after a choice is selected and still performs the merge; **Dismiss** still dismisses without merging.
5. Unauthorized users never see Review merge, Dismiss, Keep left/right, Auto-merge, or Merge patients.
6. Layout remains usable on representative desktop and narrow dialog widths and supported themes.

## Verification

- Update/extend widget tests for pair-card action alignment and merge choice order/previews (including swap updating previews).
- Manual check: open Duplicate review → confirm right-aligned card actions → Review merge → verify L/C/R actions + previews → swap a field → confirm previews change → confirm merge still works; Dismiss still works.

## Relevant Files

- `frontend/lib/features/patients/presentation/pages/patient_registry_page.dart` (`PatientDuplicateReviewDialog`, `_DuplicateReviewCard`)
- `frontend/lib/features/patients/presentation/widgets/patient_duplicate_merge_workspace.dart`
- `frontend/test/features/patients/presentation/patient_registry_page_test.dart`
- `frontend/test/features/patients/presentation/patient_duplicate_merge_workspace_test.dart`
- `frontend/lib/l10n/app_en.arb`
