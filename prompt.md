# Standardize inline form feedback with `AppFormInformationBanner`

## Objective

Refactor the Flutter app so every form uses a single, consistent pattern for inline feedback (errors, warnings, and informational messages): `AppFormInformationBanner` in `frontend/lib/shared/components/app_form_information_banner.dart`.

## Standard patterns

**Forms wrapped in `AppFormShell`** — pass feedback through `formStatus`:

```dart
AppFormShell(
  formKey: _formKey,
  formStatus: appFormFailureStatus(context, _failure),
  children: [...],
)
```

Use `appFormFailureStatus` (same file) for `AppFailure`-driven feedback. Pass `message`, `title`, `messageBuilder`, or `onRetry` only when the default presentation is insufficient.

**Forms without `AppFormShell`** — render the banner directly:

- `AppFormInformationBanner.failure(context: context, failure: _failure)` for API/submit failures
- `AppFormInformationBanner.message(...)` for non-failure guidance (validation hints, prerequisites, etc.)

Do **not** duplicate feedback: if `formStatus` is set, do not also embed a banner in `children`.

## Refactor scope

1. Replace ad-hoc inline error UI (`Text`, custom widgets, removed `AuthFailureText`, raw `failure.displayMessage` blocks, etc.) with the patterns above.
2. Migrate forms still using inline banners in `children` to `formStatus` where `AppFormShell` is present.
3. Align remaining inconsistent call sites (e.g. pharmacy workspace ternaries, radiology custom `Column` form status) with the standard helpers.
4. Remove dead code, unused imports, and redundant failure-display logic left over from the migration.
5. Keep field-level validation on inputs; use the banner for form-level / submit-level feedback only.

## Acceptance criteria

- [ ] All form submit/API failures surface through `AppFormInformationBanner` (directly or via `appFormFailureStatus`).
- [ ] No remaining references to deleted or legacy failure widgets.
- [ ] `formStatus` is the sole feedback slot on `AppFormShell` forms—no duplicate banners in `children`.
- [ ] Existing tests updated; affected widget tests assert `AppFormInformationBanner` where appropriate.
- [ ] `flutter test` passes for touched files; no new analyzer warnings.

## Out of scope

- Changing backend validation payloads or `ValidationMessagePresenter` behavior unless required to fix a broken display.
- Replacing snackbars/toasts used for post-submit navigation feedback (not inline form status).
