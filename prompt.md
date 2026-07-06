# App Dialog — Maximized by Default

## Objective

Change the default presentation of `AppDialog` so dialogs open **maximized on desktop** (breakpoint `md` and above). Apply this globally so callers do not need to pass `initialMaximized: true` unless they want a smaller initial size.

## Context

- Shared dialog: `frontend/lib/shared/components/app_dialog.dart`
- `AppDialog` already supports maximize/restore, drag, and resize on desktop via `initialMaximized`, `showMaximizeButton`, and `resizable`.
- Today `initialMaximized` defaults to `false`. Many call sites already opt in with `initialMaximized: true`.
- Key wrappers that forward the flag:
  - `frontend/lib/shared/layout/app_workspace_mutation_dialog.dart` (`showAppWorkspaceMutationDialog`)
  - `frontend/lib/shared/components/app_patient_detail_dialog.dart`
  - `frontend/lib/shared/clinical_actions/dialogs/clinical_admission_action_dialog.dart`
  - `frontend/lib/features/discharge/presentation/widgets/discharge_planning_dialog.dart`

## Requirements

1. **Default behavior** — On desktop (`AppBreakpoint.md+`), new dialogs open maximized unless explicitly overridden.
2. **Mobile / compact** — Keep current compact behavior unchanged; maximize controls remain desktop-only.
3. **Preserve restore** — Users can still restore, resize, and drag after opening; toggle behavior must remain correct.
4. **Global consistency** — Update defaults in `AppDialog` and any dialog wrappers that expose `initialMaximized`, so the app behaves consistently without per-call-site duplication.
5. **Explicit opt-out** — Call sites that need a smaller initial dialog (e.g. confirmations, simple prompts) may pass `initialMaximized: false`; audit and retain only where justified.
6. **Cleanup** — Remove redundant `initialMaximized: true` at call sites once the default is `true`.
7. **Tests** — Update `frontend/test/shared/components/app_dialog_test.dart` and any affected wrapper tests; add coverage for the new default and for explicit opt-out.

## Implementation notes

- Prefer changing constructor defaults over scattering logic at call sites.
- When `initialMaximized` is `true` at open, `_isMaximized` should initialize correctly and `_desktopSize` should reflect the maximized viewport (see existing `initState` and `_toggleMaximize` logic).
- Do not change dialog insets, theming, or unrelated dialog APIs.

## Out of scope

- Replacing `AppDialog` with a different component
- Changing mobile bottom-sheet or full-screen patterns
- Altering `showAppDialog` focus-restoration behavior

## Quality gate

From `frontend/`:

```bash
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test test/shared/components/app_dialog_test.dart
```

Run broader `flutter test` if wrapper defaults or widespread call-site cleanup changes behavior.

## Done when

- Desktop dialogs open maximized by default across the app
- Restore/maximize toggle, resize, drag, and close still work
- Redundant `initialMaximized: true` usages are removed; justified `false` overrides remain
- Tests pass and reflect the new default
