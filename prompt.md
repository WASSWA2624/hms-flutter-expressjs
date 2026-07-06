## Task

Fix the remaining **single-tap selection** bug in `AppSelectField` globally at the shared-component layer. Clear (X) is working — do not regress it.

Primary reproduction: any screen with `AppSelectField` or `AppSelectField.searchable`, including **Laboratory → Filters → Queue** (`/lab`).

## Bug

**Current behavior:** Opening the dropdown lists all options correctly. The **first click** on a menu item does not commit the selection or update the field label. A **second click** on the same item selects it and closes the menu.

**Expected behavior:** The **first click** on any enabled menu item must:

- Invoke `onChanged` / `onSelected` with that value immediately
- Update the visible label in the field
- Close the menu (unfocus)
- Apply to both `AppSelectField` and `AppSelectField.searchable`, in dialogs and inline forms

## Global application requirement

- Fix **root cause** in shared components only — not in feature pages or individual call sites.
- No lab-only or per-screen workarounds.
- Any API change must default to correct behavior so all existing consumers inherit the fix.

## Scope

| File | Change |
| --- | --- |
| `frontend/lib/shared/components/app_select_field.dart` | First-tap menu selection (primary) |
| `frontend/lib/shared/components/app_search_bar.dart` | Only if filter-dialog wiring contributes to the selection race |

**Preserve (regression guard):**

- Clear (X) resets to empty/placeholder — never auto-selects a default option
- Searchable fields show the **full option list** on menu open; filter only while the user types
- Nullable filter binding with `hintText` in `_AppSearchBarFiltersDialog`

**Out of scope:** Feature logic, `LabQueueScope`, per-page `setState` patches.

## Likely causes to investigate

- Menu rebuild or `dropdownMenuEntries` identity churn on focus/selection
- `DropdownMenuFormField` / `FormFieldState` sync racing with `onSelected`
- Focus handling (`_browseAllOptions`, `_handleFocusChanged`, `selectOnly`, `requestFocusOnTap`) consuming the first pointer event on web/desktop
- `_SelectTrailingIcon` / `AppButton` intercepting or competing with menu item taps

Note: widget tests may pass while the running web app still double-taps — verify manually.

## Acceptance criteria

- [ ] First tap on a menu item selects it and closes the menu (non-searchable and searchable).
- [ ] Clear (X) still resets to placeholder/empty — not a default option.
- [ ] Searchable reopen still shows all options before typing.
- [ ] Filter dialogs (`AppSearchBar`) behave the same as standalone selects.
- [ ] Existing tests pass, especially:
  - `AppSelectField selects an option with one tap`
  - `AppSelectField.searchable selects an option with one tap`
  - `AppSelectField clear button clears the selected value`
  - `AppSelectField.searchable shows all options when menu reopens with a selection`
  - `filter dialog clear leaves placeholder instead of All option`
  - `filter dialog shows all options when reopening menu with a selection`
- [ ] Add a test only if it reproduces the runtime failure not covered above.

## Verification

```bash
cd frontend
flutter test test/shared/components/app_form_components_test.dart
flutter test test/shared/components/app_search_bar_test.dart
dart analyze lib/shared/components/app_select_field.dart lib/shared/components/app_search_bar.dart
```

Manual smoke test on web:

1. `/lab` → **Filters** → **Queue** → open menu → tap **Processing** once → label updates, menu closes.
2. Tap **X** → placeholder only (not selected "All").
3. Repeat on at least one non-lab `AppSelectField` screen.
