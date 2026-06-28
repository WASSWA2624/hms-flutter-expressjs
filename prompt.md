# Global Form Input Uniformity — Floating Labels

## Objective

Standardize every user-editable form input across the HMS Flutter frontend so labels use the **floating-label pattern** consistently. The app should look and behave the same whether the field appears on a page, inside a dialog, inside a drawer, or nested within another form.

**Reference implementation:** Auth flows already demonstrate the target UX — see `frontend/lib/features/auth/presentation/pages/login_page.dart`, `register_page.dart`, and related auth widgets where `AppTextField` is used with `useFloatingLabel: true`.

---

## Scope

### In scope

All components where the user types, selects, or edits structured data, including but not limited to:

| Component | Location |
|-----------|----------|
| `AppTextField` | `shared/components/app_text_field.dart` |
| `AppSelectField` | `shared/components/app_select_field.dart` |
| `AppDateField` | `shared/components/app_date_field.dart` |
| `AppTimeField` | `shared/components/app_time_field.dart` |
| `AppEmailField` | `shared/components/app_email_field.dart` |
| `AppPhoneField` | `shared/components/app_phone_field.dart` |
| `AppCurrencyAmountField` | `shared/components/app_currency_amount_field.dart` |
| `AppGenderField` | `shared/components/app_gender_field.dart` (if applicable) |
| Any wrapper or composite field built on top of the above | e.g. `app_vitals_form.dart`, clinical action dialogs, workspace pages |

Applies everywhere these appear: workspace pages, setup wizards, `AppDialog` forms, action dialogs, catalog panels, and nested sub-forms.

### Out of scope

- **Buttons** (`AppButton`, icon buttons, toggles that are not data-entry fields).
- **Read-only display** widgets (`AppInfoTile`, status text, table cells showing data).
- **Checkboxes / radio / switch** groups — keep existing label layout unless they already wrap a text/select field.
- **Search bars used purely as list filters** (`AppSearchBar` toolbar filters) — only migrate if they contain editable text/select filters that should match form-field styling; do not redesign the search-bar UX beyond label consistency.

---

## Current gaps (known)

1. **`AppTextField.useFloatingLabel` defaults to `false`.** Most of the app renders an external label above the field instead of a floating label inside the decoration. Only auth pages pass `useFloatingLabel: true` explicitly.
2. **Wrapper fields do not propagate floating labels.** `AppTimeField`, `AppEmailField`, and similar wrappers delegate to `AppTextField` without enabling floating labels.
3. **Raw Flutter field usage bypasses shared components.** Direct `TextFormField`, `TextField`, `DropdownButtonFormField`, or hand-rolled `InputDecoration(labelText: …)` appear in:
   - `shared/components/app_vitals_form.dart`
   - `shared/components/app_currency_amount_field.dart`
   - `shared/components/app_phone_field.dart` (country-code search)
   - `shared/components/app_search_bar.dart`
   - `features/settings/presentation/widgets/settings_workspace_section.dart`
4. **`AppSelectField` and `AppDateField` already use floating labels** via `DropdownMenuFormField.label` and `InputDecorator` + `appFieldLabelWidget`. Treat these as the pattern to match, not rewrite.
5. **Duplicate label rendering.** When floating labels are enabled, external/stacked labels above the field must be removed to avoid double labels.

---

## Implementation strategy

Work in this order. Prefer fixing shared components first so call sites inherit the behavior automatically.

### Phase 1 — Shared component defaults

1. **Change `AppTextField` default:** set `useFloatingLabel = true`.
   - Preserve rich required/optional indicators via `appFieldLabelWidget` inside the decoration (already implemented when `useFloatingLabel` is true).
   - Keep `FloatingLabelBehavior.auto` for text fields.
   - Remove or guard the external label column so it never renders when floating labels are active.

2. **Update field wrappers** to either remove their own `useFloatingLabel` parameter (inherit default) or default it to `true`:
   - `AppEmailField`
   - `AppPhoneField` (including any internal sub-fields)
   - `AppTimeField`
   - `AppCurrencyAmountField`

3. **Align composite fields:**
   - `AppDateField` — already compliant; verify sub-part hints (DD/MM/YYYY) do not conflict visually.
   - `AppSelectField` — already compliant; verify sizing/padding matches `AppTextField`.
   - `AppVitalsForm` — replace raw `DropdownButtonFormField` + `InputDecoration(labelText: …)` with `AppSelectField` or apply the same floating-label decoration pattern.

4. **Remove redundant per-call-site `useFloatingLabel: true`** in auth pages once the default is true (optional cleanup).

### Phase 2 — Audit and migrate call sites

Run a repo-wide audit under `frontend/lib/`:

```bash
# Raw Flutter inputs (should be zero outside shared components after migration)
rg "TextFormField\(|TextField\(|DropdownButtonFormField\(|InputDecoration\(" frontend/lib --glob "*.dart"

# External-label mode still explicitly disabled (review each)
rg "useFloatingLabel:\s*false" frontend/lib --glob "*.dart"

# Legacy stacked labels above fields (manual review)
rg "labelText:" frontend/lib --glob "*.dart"
```

For every hit outside `shared/components/`:

- Replace raw inputs with the appropriate `App*` component.
- Pass `labelText`, `hintText`, `isRequired`, validators, and controllers as today — do not drop accessibility or validation behavior.
- Do **not** add a separate `Text` label above the field when the shared component already renders a floating label.

### Phase 3 — Visual and UX consistency

Ensure all form inputs share:

- **Height** — respect `theme.inputDecorationTheme.constraints` (min height ~48).
- **Typography** — body text `bodyLarge`, label `labelLarge` / field label style from theme.
- **Spacing** — use `theme.spacing.*` between fields (typically `md`), consistent with auth forms.
- **Required / optional markers** — use `isRequired: true` and `(optional)` suffix parsing via `app_field_label.dart`; never hard-code `*` in l10n strings unless already standardized.
- **Error / helper text** — render through the shared component's `errorText` / `helperText`, not a separate widget below unless the component requires it.

Use `AppFormShell`, `AppFormSection`, and `AppResponsiveFieldRow` (`shared/forms/`) for layout — do not introduce one-off column/wrap spacing for forms.

### Phase 4 — Cleanup

- Delete dead helpers, duplicate field widgets, or legacy decoration builders that exist only to support the old external-label pattern.
- Remove unused imports after migrations.
- Do not leave both an old and new field implementation for the same use case.

---

## Acceptance criteria

- [ ] Every editable form field in `frontend/lib/` uses a shared `App*` input component (or a composite built exclusively from them).
- [ ] No field shows **both** an external label and a floating label.
- [ ] `AppTextField` (and wrappers) default to floating labels; auth and non-auth screens look identical in label behavior.
- [ ] `AppSelectField`, `AppDateField`, `AppTextField`, and currency/phone/email/time fields have matching height, border radius, and label animation.
- [ ] Raw `TextFormField` / `TextField` / `DropdownButtonFormField` usage is confined to shared component internals (grep audit passes).
- [ ] Existing tests pass; update widget tests if they assert on external label widgets or label text placement.
- [ ] Run `dart analyze` on touched files with no new issues.

---

## Verification

1. **Automated:** run existing frontend tests, especially component and dialog tests under `frontend/test/shared/components/`.
2. **Manual smoke test** these surfaces (forms in dialogs and full pages):
   - Auth (login, register, forgot/reset password)
   - Tenant/facility setup
   - Patient registry create/edit
   - Lab catalog dialogs
   - HR, billing, and clinical action dialogs
   - Settings workspace filters (if migrated)
3. **Visual check:** empty, focused, filled, error, and disabled states for text, select, date, and currency fields at desktop and compact widths.

---

## Constraints

- **Minimize diff scope per file** — change only what is required for label uniformity; do not refactor unrelated logic.
- **Preserve behavior** — validation, autofill, focus order, restoration IDs, and semantics must remain intact.
- **Follow existing conventions** — match naming, imports (`shared/components/components.dart`), and l10n usage already in the codebase.
- **No new dependencies.**
