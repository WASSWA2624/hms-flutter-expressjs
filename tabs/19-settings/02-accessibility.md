# Settings section — Accessibility

## 1. Section chrome

- Label: `settingsAccessibilitySectionTitle` / body `settingsAccessibilitySectionBody`
- Icon: `accessibility_new_outlined`
- Deep-link `tab`: `accessibility`
- Expand: strip + accordion; own `AppCollapsibleSection`
- Gate: `SettingsAccessibilityAtomPermissions.tab` = `profileReadRequirement`
- **Omitted when unauthorized**

## 2. Search / Filters / Settings / Export / Print / context

- Absent

## 3. Inner surfaces

- Checkboxes: `settingsReduceMotionLabel`/`Description`, `settingsBoldTextLabel`/`Description`
- Select: `settingsTextScaleFieldLabel` → Normal / Large / Extra large
- Read-only rows use `commonYesLabel` / `commonNoLabel` — same dead path as Preferences (`update` ≡ `profile:read`)

## 4. Advanced filters / search fields

- Absent

## 5. Primary / secondary / row actions

- Immediate persist on change
- Create/delete ∩ `facility:admin` — **not mounted**

## 6. Dialogs from this section

| Dialog | Owner |
| --- | --- |
| — | none |

## 7. Nested / follow-on

- None

## 8. Forms (summary)

- Three a11y controls (reduce motion, bold text, text scale)

## 9. Print / labels / preview

- Absent

## 10. Loading / empty / error / success

- Error: `settingsSaveErrorMessage`; no success snackbar

## 11. RBAC / ABAC (omitted when unauthorized)

| Atom | Gate |
| --- | --- |
| Tab / values / controls | ∩ `profile:read` |
| Create / delete | ∩ `facility:admin` — not mounted |
