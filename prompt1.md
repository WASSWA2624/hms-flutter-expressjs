# Refactor Settings Page Sections into an Accordion Layout

## Objective

Replace the current vertically stacked grid layout of the Settings page (`frontend/lib/features/settings/presentation/pages/settings_page.dart`) with an **accordion (single-expand) pattern** to optimize vertical space. All sections start collapsed; only one section can be expanded at a time.

---

## Scope

### Sections to convert

The following sections currently rendered inside `_SettingsSectionGrid` and below it must each become a collapsible accordion panel:

1. **Preferences** (`settingsPreferencesSectionTitle`) — theme mode radio group
2. **Accessibility** (`settingsAccessibilitySectionTitle`) — reduce motion, bold text, text scale
3. **Account and security** (`settingsAccountSectionTitle`) — profile link, change password
4. **Administration boundaries** (`settingsAdministrationSectionTitle`) — conditional on `adminActions.isNotEmpty`
5. **Configuration** (`SettingsConfigurationSection`) — currency and consultation fee setup
6. **Administrative setup workspace** (`SettingsWorkspaceSection`) — conditional on `showSettingsWorkspace`

### Behaviour

- **Initial state**: all sections collapsed.
- **Single expand**: tapping a collapsed header expands it and collapses any previously expanded section.
- **Tapping the expanded header**: collapses it, leaving all sections collapsed.
- **Collapsed appearance**: each section header renders as a compact, horizontally-arranged **tab-like strip** showing the section icon and title. All collapsed headers sit together at the top of the settings body, visually resembling a tab bar or chip row.
- **Expanded appearance**: the selected section's content expands **below** the tab strip, pushing subsequent content down.
- **Conditional sections**: sections gated by RBAC or feature flags (Administration boundaries, Configuration, Administrative setup workspace) must remain hidden when their visibility conditions are not met — they should not appear in the tab strip at all.

### UX Details

- Use smooth expand/collapse animation consistent with the app's `reduceMotion` accessibility preference.
- Preserve scroll position when switching sections — avoid jumping to the top.
- The expanded section's full content must remain fully responsive (the current responsive behaviour within each section must be preserved).
- Keyboard accessibility: tab strip items must be focusable and activatable via Enter/Space.

---

## Technical Constraints

- **Architecture**: keep changes within `settings_page.dart` and, if needed, a new reusable widget under `frontend/lib/shared/` (e.g. `AppAccordion` or `AppCollapsibleSectionGroup`).
- **State management**: use local widget state (`StatefulWidget`) — no Riverpod provider is needed for expand/collapse state.
- **Reusable components**: if a new accordion/collapsible widget is created, place it in `frontend/lib/shared/components/` so it can be reused elsewhere.
- **Localization**: all text must continue to use existing `l10n` keys. No new strings are needed unless a new accessibility label is required for the tab strip.
- **Responsiveness**: on narrow screens (mobile), the tab strip may wrap to multiple lines. On wider screens, it should lay out horizontally.
- **No regressions**: the existing functionality within each section (theme switching, accessibility toggles, navigation actions, configuration saves, workspace loading) must remain unchanged.
