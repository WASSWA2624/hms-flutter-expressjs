# Settings section — Preferences

## 1. Section chrome

- Label: `settingsPreferencesSectionTitle` / body `settingsPreferencesSectionBody`
- Icon: `palette_outlined`
- Deep-link `tab`: `preferences` (default; omitted from URL)
- Expand: strip + single-expand accordion; own `AppCollapsibleSection`
- Gate: `SettingsPreferencesAtomPermissions.tab` = `profileReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- **All absent**

## 3. Inner surfaces

- Update path: `AppRadioGroup<ThemeMode>` — System / Light / Dark
- Read-only path: `_PreferencesReadOnlySummary` — **unreachable today** because `update` ≡ `tab` ≡ `profile:read`
- Keys: `settingsThemeModeFieldLabel`, `settingsThemeModeSystem` (+`Description`), `Light`, `Dark`

## 4. Advanced filters / search fields

- Absent

## 5. Primary / secondary / row actions

- Immediate save on radio change (no Save button)
- Create/delete: matrix ∩ `facility:admin` — **not mounted**

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| — | none |

## 7. Nested / follow-on

- None

## 8. Forms (summary)

- Theme radio group only
- **Not mounted** despite arb: `settingsLanguage*` / `settingsThemeSection*` standalone section keys

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Local prefs (no async list load)
- Error snackbar: `settingsSaveErrorMessage`
- No success snackbar

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / chrome / theme value / theme radios / feedback | ∩ `profile:read` |
| Create / delete | ∩ `facility:admin` — not mounted |
| Nested | n/a |
