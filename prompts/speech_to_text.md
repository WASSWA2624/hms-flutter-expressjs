# Shared speech-to-text on text inputs

Add a consistent microphone speech-to-text affordance to shared text inputs so clinicians and staff can dictate into plain and rich text fields on web, Android, iOS, and desktop.

## Context

- Shared inputs live under `frontend/lib/shared/components/`.
- Primary targets: `AppTextField` and `AppRichTextEditor` (clinical notes and other free-text surfaces already use these).
- `AppRichTextEditor` stores lightweight markdown-ish plain `String` (not Delta/HTML). Keep that model; insert transcribed plain text at the caret. Do **not** migrate the editor to Flutter Quill in this work.
- Connectivity: `connectivity_plus` is already in `frontend/pubspec.yaml`. Prefer it for online/offline gating.
- Recognition: add and use the `speech_to_text` package, relying on each platform’s built-in speech recognition when available.
- Follow `.cursor/locale-development.mdc` for English strings and `.cursor/mandatories.mdc` for loading/responsive/feedback invariants.
- Theme and icon buttons must match existing suffix patterns in `AppTextField` (clear / obscure toggles already compose in the suffix row).



## Requirements

1. Introduce a reusable speech-to-text control (e.g. `AppSpeechToTextButton` or equivalent) that:
  - Shows a compact **microphone** icon button when idle.
  - Switches to a **stop** (square) icon while listening/recording.
  - Is **disabled** when offline, when speech is unavailable on the platform, when the field is disabled/read-only, or while permissions are denied / mic hardware is missing.
  - Is **enabled** when online, the field is editable, and recognition + mic are available (or after a successful permission grant).
2. Wire the control into `AppTextField` by default for editable free-text fields (compose with existing clear / password suffix actions). Provide an explicit opt-out (e.g. `enableSpeechToText: false`) for passwords, secrets, purely numeric/code fields, and any caller that must not dictate.
3. Wire the same control into `AppRichTextEditor` so dictation inserts plain text at the current selection/caret without stripping existing markup elsewhere in the document.
4. On start: request mic permission if needed; start listening; stream or final results into the field’s `TextEditingController` at the caret (append/replace selection). Manual typing must remain possible while not listening; stop listening cleanly on stop tap, dispose, field disable, or unmount.
5. Surface clear, localized feedback for: listening, offline, mic permission required/denied, no microphone, recognition unavailable, and generic recognition errors (tooltip and/or short helper/snackbar—match existing field feedback patterns; no silent failure).
6. Support **Android, iOS, and desktop** (Windows/macOS/Linux as applicable). Where platform STT is missing or unsupported, keep the control visible but disabled with an unavailable reason—do not crash or throw into the form.
7. Only one field should listen at a time: starting speech on another field stops the previous session after a warning.
8. Add English l10n keys in `app_en.arb` for button labels, tooltips, and status/error messages; regenerate localizations as required by the frontend i18n flow.
9. Cover with widget/unit tests: idle → listening → stop icon; offline disables; opt-out hides/disables; text is inserted into the controller; rich text caret insert preserves surrounding markup markers.

Optional enhancements: none.

## Constraints

- Reuse `AppTextField` / `AppRichTextEditor` / `AppButton` icon-only patterns and theme tokens; do not fork per-feature mic UIs.
- Do not replace `AppRichTextEditor` with Flutter Quill or change clinical note storage format.
- Prefer platform STT via `speech_to_text`; no custom cloud STT backend in this change.
- Offline ⇒ inactive control (recognition assumed network-dependent where the platform requires it).
- No speech on `obscureText` / password fields; default opt-out for non-text keyboard types when dictation would be harmful (e.g. pure number/phone if product prefers typing-only—document the default in code).
- No unrelated refactors outside shared input speech wiring, connectivity gating, l10n, and tests.
- Responsive: mic/stop targets remain tappable on mobile and unobtrusive on desktop dense forms.



## Acceptance Criteria

- AC1 (Req 1–2): Editable `AppTextField` instances show a mic suffix; while listening it shows stop; offline/unavailable/disabled states gray out the control with a localized reason.
- AC2 (Req 2): Password/obscured and explicitly opted-out fields never expose speech controls.
- AC3 (Req 3–4): Dictation into `AppRichTextEditor` and `AppTextField` inserts recognized text at the caret; stop ends listening; dispose/unmount does not leak sessions.
- AC4 (Req 5–6): Permission denied, missing mic, offline, and unsupported platform show clear disabled/error feedback without crashing.
- AC5 (Req 7): Starting speech on a second field stops the first.
- AC6 (Req 8–9): English strings and tests cover the states above; light and dark theming remain coherent.



## Relevant Files

- `frontend/lib/shared/components/app_text_field.dart`
- `frontend/lib/shared/components/app_rich_text_editor.dart`
- `frontend/lib/shared/components/components.dart`
- `frontend/lib/shared/components/app_button.dart`
- `frontend/pubspec.yaml` (`speech_to_text`, existing `connectivity_plus`)
- `frontend/lib/l10n/app_en.arb`
- `frontend/test/shared/components/`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`

