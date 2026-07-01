# French Localization — Implementation Prompt

## Objective

Add **French (`fr`)** as the first additional locale for HOSSPI HMS and verify end-to-end localization on the frontend and backend. English (`en`) remains the **base locale** for all new development.

**Related work:** [prompts/06-settings-profile-module-prompt.md](./prompts/06-settings-profile-module-prompt.md) (language preference UI).

---

## Protective Rule (create first)

Add an **always-on** Cursor rule at `.cursor/locale-development.mdc` that applies to the whole monorepo:

| Rule | Requirement |
| ---- | ----------- |
| Base locale | `en` is the sole source of truth during day-to-day development |
| Frontend | Only edit `frontend/lib/l10n/app_en.arb` unless the user explicitly asks to update other ARB files |
| Backend | Only edit `backend/src/locales/en.json` unless the user explicitly asks to update other locale JSON files |
| New keys | Add strings to English first; do not bulk-translate or sync non-English locale files proactively |
| Explicit override | Update `app_fr.arb`, `fr.json`, or other non-English files **only** when the user instructs (e.g. “translate French”, “sync fr locale”) |

Register the rule in [`.cursor/index.mdc`](./.cursor/index.mdc) under always-applied or high-priority rules.

---

## Current State (read before changing code)

| Area | Location | Notes |
| ---- | -------- | ----- |
| Frontend strings | `frontend/lib/l10n/app_en.arb` | Only English ARB exists today |
| L10n config | `frontend/l10n.yaml` | `preferred-supported-locales: [en]` |
| Language picker | `frontend/lib/features/settings/presentation/pages/settings_page.dart` | English only; `_LanguageFlag` shows text codes (`EN`), not flags |
| Locale persistence | `frontend/lib/app/locale/app_locale_controller.dart` | Persists user choice locally |
| Backend strings | `backend/src/locales/en.json` | Only English JSON exists |
| Supported locales | `backend/src/config/constants.js` → `SUPPORTED_LOCALES` | `['en']` only |
| Stack rules | `frontend/.cursor/localization_i18n.mdc`, `backend/.cursor/internationalization.mdc` | Follow existing i18n conventions |

---

## Scope

### 1. Frontend

- Add `frontend/lib/l10n/app_fr.arb` with French translations for existing keys (mirror `app_en.arb` structure).
- Register `fr` in `l10n.yaml` and ensure `AppLocalizations.supportedLocales` includes French after `flutter gen-l10n`.
- Extend the Settings language `AppSelectField` with a **French** option.
- Show a **flag icon per language** in the selector (English and French); reuse or extend `_LanguageFlag` — use real flag assets or consistent emoji/SVG, not plain text codes.
- Add `settingsLanguageFrench` (and any related labels) to `app_en.arb`; include French equivalents in `app_fr.arb`.
- Selecting French must update the UI immediately and persist via `AppLocaleController`.

### 2. Backend

- Add `fr` to `SUPPORTED_LOCALES` in `backend/src/config/constants.js`.
- Add `backend/src/locales/fr.json` with French translations for all keys in `en.json`.
- Confirm locale resolution (`x-locale`, query `locale`, `Accept-Language`) returns French messages when requested.
- Ensure API requests from the Flutter client pass the active user locale where applicable.

### 3. Verification

- Switch language in **Settings → Preferences → App language** and confirm UI strings change (navigation, settings, at least one clinical workspace screen).
- Trigger a backend error/success message with `locale=fr` (or `x-locale: fr`) and confirm French copy is returned.
- English remains the fallback when a key is missing in French.

---

## Constraints

- Do **not** hard-code user-facing strings in widgets or backend handlers.
- Do **not** modify non-English locale files during routine feature work — per the protective rule above.
- Clinical/user-entered data is never auto-translated; only system UI and API messages are localized.
- Match existing patterns: `context.l10n` / `AppLocalizations` on frontend; `translate()` on backend.

---

## Acceptance Criteria

- [ ] French is selectable in Settings with a visible flag; choice persists across restart.
- [ ] App UI renders in French when French is selected; reverts to English when switched back.
- [ ] Backend serves French messages for supported keys when locale is `fr`.
- [ ] `.cursor/locale-development.mdc` exists, is always applied, and is indexed at repo root.
- [ ] `flutter analyze`, `flutter test`, and targeted backend i18n tests pass.

---

## Quality Gate

From `frontend/`:

```sh
flutter pub get
flutter gen-l10n
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

From `backend/`:

```sh
npm test -- --testPathPattern="i18n"
```

---

## Key File References

```
.cursor/locale-development.mdc          # new protective rule
frontend/lib/l10n/app_en.arb
frontend/lib/l10n/app_fr.arb              # new
frontend/l10n.yaml
frontend/lib/features/settings/presentation/pages/settings_page.dart
frontend/lib/app/locale/app_locale_controller.dart
backend/src/config/constants.js
backend/src/locales/en.json
backend/src/locales/fr.json               # new
backend/src/lib/i18n/
```
