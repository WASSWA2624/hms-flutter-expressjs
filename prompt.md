## Task

Fix `AppSelectField` interaction bugs **globally** at the shared-component layer so every screen, dialog, and filter across the app benefits without per-feature patches.

Primary reproduction case: **Laboratory → Patient lab worklist → Filters → Queue** (`/lab`). Use it to validate; do **not** limit the fix to lab or filter dialogs only.

## Global application requirement

- Fix **root cause** in shared components — not in feature pages, workspace controllers, or individual dialog call sites.
- **No** lab-only, module-only, or one-off workarounds (e.g. do not special-case `lab_workspace_page.dart`, `LabQueueScope`, or a single filter key).
- Any new API on `AppSelectField` or `AppSearchBar` must default to the correct behavior so existing call sites inherit the fix automatically.
- After the change, **all** `AppSelectField` and `AppSelectField.searchable` usages (forms, dialogs, filter panels, pickers, settings, HR, billing, pharmacy, etc.) must behave consistently — no follow-up per-screen fixes expected.

## Observed bugs (from screenshots)

### 1. Clear (X) does not reset to an empty field

**Current behavior:** Tapping **X** on a select (e.g. Queue with “Awaiting results”) does not leave the field blank. It immediately shows **“All”** as the selected value.

**Expected behavior (all usages):** Clear must reset the field to an **unselected** state:

- Empty text controller
- Only `hintText` / placeholder visible (no option label shown)
- `onChanged(null)` fired so parent state treats the value as unset
- **Do not** auto-select a sentinel “All” (or any default) option on clear

**Root-cause hint:** `_AppSearchBarFiltersDialog` binds filter selects with `value: _options[group.key] ?? _allValue`, so a cleared/null value is coerced back to “All”. The shared filter-dialog pattern must be fixed once for every filter group.

### 2. Open menu shows a filtered subset, not all options

**Current behavior:** Opening a searchable select while a value is selected only shows options matching the current label text. Examples:

- Value **“All”** → menu shows only “All”
- Value **“Awaiting results”** → menu shows a narrowed list instead of every option

**Expected behavior (all usages):** Opening the menu must list **all** options. Typing filters only while the user is actively searching — not based on the previously committed selection label.

**Root-cause hint:** `AppSelectField.searchable` filters `_menuOptions()` using `_controller.text` even when the menu is first opened with a committed selection.

### 3. Option selection requires two clicks

**Current behavior:** Choosing a menu item often needs two taps before the value commits and the label updates.

**Expected behavior (all usages):** One tap on a menu item must select it, update the visible label, and close the menu. Applies to both `AppSelectField` and `AppSelectField.searchable`.

## Scope

| File | Global change |
| --- | --- |
| `frontend/lib/shared/components/app_select_field.dart` | Clear, menu-open option list, single-tap selection — default behavior for every consumer |
| `frontend/lib/shared/components/app_search_bar.dart` | Nullable/unselected filter binding in `_AppSearchBarFiltersDialog` — all filter dialogs site-wide |

**In scope:** Shared component fixes and their tests only.

**Out of scope:** Feature-specific logic, per-page `setState` patches, lab queue semantics, or duplicating select widgets outside the shared layer.

- Preserve existing public API where possible; new parameters must default to the corrected global behavior.
- “No selection” in filter UIs must still map to “show all records” on **Apply filters** (same as today’s empty `AppSearchBarFilterValue`).

## Acceptance criteria

### Component-level (global)

- [ ] `AppSelectField` clear (X) resets to empty/placeholder everywhere — never auto-selects a default option.
- [ ] `AppSelectField.searchable` shows the full option list on menu open in every context.
- [ ] One-tap selection works for both searchable and non-searchable variants app-wide.
- [ ] `_AppSearchBarFiltersDialog` applies the same clear/open/select behavior to **every** filter group and search-field select — not only Queue.

### Regression surfaces (sample verification — fix must not require per-screen code)

- [ ] **Laboratory filters → Queue** (`/lab`)
- [ ] **Any other module** using `AppSearchBar` advanced filters (e.g. OPD, pharmacy catalog, radiology, HR)
- [ ] **Standalone `AppSelectField`** in forms/dialogs (patient registration, billing, lab order dialogs, settings)

### Tests

- [ ] Existing tests pass; add/adjust tests in:
  - `frontend/test/shared/components/app_form_components_test.dart`
  - `frontend/test/shared/components/app_search_bar_test.dart` (if present)
- [ ] Tests assert global component behavior, not lab-specific strings or scopes.

## Verification

```bash
cd frontend
flutter test test/shared/components/
dart analyze lib/shared/components/app_select_field.dart lib/shared/components/app_search_bar.dart
```

Manual smoke test (minimum):

1. `/lab` → **Filters** → Queue: select, clear (X), reopen — full list, placeholder on clear, one-tap select.
2. At least **one non-lab screen** with `AppSelectField` or `AppSearchBar` filters — confirm identical clear/open/select behavior.
3. Confirm no feature-page diffs were needed for the fix to work globally.
