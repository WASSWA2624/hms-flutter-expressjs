## Task

Fix two interaction bugs in `frontend/lib/shared/components/app_select_field.dart` (`AppSelectField`).

## Bugs

### 1. Clear button does not reset the field

**Current behavior:** Tapping the trailing **X** (clear) icon does not fully clear the selection. The displayed value may remain instead of reverting to the placeholder.

**Expected behavior:** When `allowClear` is true and `onChanged` is provided, tapping **X** must:

- Call `onChanged(null)`
- Clear the text controller
- Reset `DropdownMenuFormField` selection so only `hintText` is shown
- Work for both controlled usage (`value` + parent `setState`) and internal state

### 2. First menu tap does not select an option

**Current behavior:** Choosing an option often requires two taps—the first tap does not commit the selection or update the displayed label.

**Expected behavior:** A single tap on a menu item must:

- Invoke `onSelected` / `onChanged` with the chosen value on the first interaction
- Update the visible label immediately
- Close the menu (unfocus) after selection
- Apply to both `AppSelectField` and `AppSelectField.searchable`

## Scope

- Fix root cause in `app_select_field.dart` only; do not change unrelated components or call sites unless required for correct controlled/uncontrolled behavior.
- Preserve existing API, styling, search/filter behavior, and accessibility semantics.
- Match surrounding code style and patterns.

## Acceptance criteria

- [ ] Clear (**X**) resets the field to empty/placeholder in the running app.
- [ ] One tap selects an option and shows its label without a second tap.
- [ ] Existing tests in `frontend/test/shared/components/app_form_components_test.dart` pass, especially:
  - `AppSelectField clear button clears the selected value`
  - `AppSelectField.searchable selects an option with one tap`
- [ ] Add or adjust tests only if they expose a real gap not covered by the cases above.

## Verification

From `frontend/`:

```bash
flutter test test/shared/components/app_form_components_test.dart
```

Manually verify on web or device: select a value, confirm it appears on first tap; tap **X**, confirm placeholder returns.
