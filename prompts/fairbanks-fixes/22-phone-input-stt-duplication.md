# 22 — Fix Phone Number and Speech-to-Text Duplication

**Source:** [fairbanks-fixes.md](../fairbanks-fixes.md) → Phase 7, Step 22
**Depends on:** none
**Applies to:** development and production

## Context

Dictating into the shared phone field produces duplicated values such as `+256... +256...`. The shared component is `frontend/lib/shared/components/app_phone_field.dart`, with dictation from `app_speech_to_text.dart`; a fix there must hold everywhere the field is used.

## Requirements

1. Identify the duplication mechanism in the shared phone field: whether recognition results append instead of replace, whether partial and final results are both committed, whether the controller text and the parent state both apply the update, or whether a rebuild re-applies the last result.
2. Make the field a single source of truth for its value, so a recognition result replaces the dictated segment rather than appending to an already-updated value.
3. Handle partial and final speech results explicitly: only the final result is committed, and an interrupted or cancelled session leaves the previous value intact.
4. Preserve country code and number formatting: dictation must not duplicate, drop, or re-prefix the dialing code, and the normalized value sent to the API must remain valid.
5. Keep typing, pasting, and editing behavior unchanged, including cursor position after a dictation commit.
6. Ensure repeated dictation, dictation after typing, and dictation on an existing value each produce exactly one well-formed number.
7. Ensure component reopening and rerendering do not re-apply a previous recognition result.
8. Add widget tests covering: dictation only, typing only, dictation then typing, repeated dictation, rebuild during dictation, reopening the component, and editing an existing value.
9. Verify every usage site of the shared phone field and speech-to-text component after the fix.
10. Ship the change to both development and production per **Rollout** below.

## Constraints

- Fix the shared component; do not patch individual screens or add per-screen deduplication.
- Do not change the public API of the shared field in a way that breaks existing call sites without updating them.
- Follow `prompts/.cursor/forms.mdc` and `localization.mdc`.

## Acceptance Criteria

- [ ] **AC1 (R1)** The duplication mechanism is identified and stated in the pull request description.
- [ ] **AC2 (R2, R3, R6)** Each scenario in R6 and R8 yields exactly one well-formed number.
- [ ] **AC3 (R4)** The dialing code appears once and the normalized value passes existing phone validation.
- [ ] **AC4 (R5)** Typing, pasting, editing, and cursor position behave as before.
- [ ] **AC5 (R7)** Reopening or rebuilding the component never re-applies a prior result.
- [ ] **AC6 (R8)** New widget tests pass and fail against the pre-fix component.
- [ ] **AC7 (R9)** Every usage site is verified, with the list recorded in the pull request description.
- [ ] **AC8 (R10)** Behavior is identical in development and production builds.

## Verification

- `flutter analyze`, `flutter test` in `frontend/`.
- Manual: dictation on Android (real microphone) and on the web build, in both environments, across at least three screens that use the field.

## Rollout — Development and Production

- Behavior must be identical under both Flutter define files; no dictation behavior may depend on a development-only flag.
- Config: mirror any speech or locale define in `frontend/env/development.json.example` and `frontend/env/production.json.example`.
- Schema/data: none.
- Release: `python deploy/deploy-frontend.py` and `python deploy/deploy-android.py`, then repeat the dictation scenarios against `https://app.hosspi.com` and the release APK.

## Relevant Files

- `frontend/lib/shared/components/app_phone_field.dart`
- `frontend/lib/shared/components/app_speech_to_text.dart`, `app_speech_ai.dart`
- `frontend/lib/shared/components/components.dart`
- `frontend/test/shared/components/`
