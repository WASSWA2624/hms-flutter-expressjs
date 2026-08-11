# Settings — shared / cross-section chrome

## Shell entry

- Route: `AppRoutes.settings` (`/settings`) under app `ShellRoute`
- Catalog: `RouteAccessCatalog.settings` → `authenticatedCore` (empty `AccessRequirement`)
- `/profile` **redirects** → `SettingsPageQuery(tab: 'account', panel: 'profile')`
- User menu: Settings → `/settings`; Profile → `?tab=account&panel=profile`; Change password → `?tab=account&panel=change-password`

## Page chrome

- `ResponsivePage` (`PageMaxWidth.dashboard`, workspace padding)
- No `AsyncStateScaffold` / workspace-wide loading at page level
- Body: `_SettingsAccordion` = `AppTabStrip` + animated `_AccordionPanel`s
- Query model: `SettingsPageQuery` — `tab` (default `'preferences'`), optional `panel`
  - `location()` omits `tab` when `preferences`; includes `panel` when non-empty
- Expand: **exactly one** section; retap selected is a no-op (cannot collapse to empty shell)
- Tap → `go(SettingsPageQuery(tab: sectionId))` — **clears `panel`**
- If URL tab not in visible list → first visible section
- Motion: expand/collapse 150ms; `Duration.zero` when `appAccessibilityProvider.reduceMotion`
- Lazy mount: panel body built only after first expand (`_hasBeenExpanded`)
- Accordion `wrapInSection: false` for all entries — each section owns its own `AppCollapsibleSection` (Account is the exception: no section title/body chrome)

## Strip order / ids / icons / gates

| Order | `tab` id | Icon | Title key | Visibility |
| --- | --- | --- | --- | --- |
| 1 | `preferences` | `palette_outlined` | `settingsPreferencesSectionTitle` | `SettingsPreferencesAtomPermissions.tab` = `profileReadRequirement` |
| 2 | `accessibility` | `accessibility_new_outlined` | `settingsAccessibilitySectionTitle` | `SettingsAccessibilityAtomPermissions.tab` = `profileReadRequirement` |
| 3 | `account` | `shield_outlined` | `settingsAccountSectionTitle` | `SettingsAccountAtomPermissions.tab` = `profileReadRequirement` |
| 4 | `leaves` | `event_busy_outlined` | `settingsLeavesSectionTitle` | `SettingsLeavesAtomPermissions.tab` = `profileReadRequirement` |
| 5 | `rosters` | `calendar_month_outlined` | `settingsRostersSectionTitle` | `SettingsRostersAtomPermissions.tab` = `profileReadRequirement` |
| 6 | `administration` | `admin_panel_settings_outlined` | `settingsAdministrationSectionTitle` | `settingsAdministrationSectionVisible` |
| 7 | `configuration` | `tune_outlined` | `settingsConfigurationSectionTitle` | `settingsConfigurationSectionVisible` |
| 8 | `workspace` | `build_outlined` | `settingsWorkspaceSectionTitle` | `settingsWorkspaceSectionVisible` |

- Strip: **no counts / no count tones**
- Strip uses section **title** only; entry `body` keys are unused at accordion level
- Sections **omitted** when unauthorized — not disabled

## Shared toolbar pattern

- **Absent** page-wide: Search / Filters / Table Settings / Export / Print
- Per-section toolbars where present (Account Change password / Edit profile; Leaves request; Configuration Save/Reset; Workspace filters)

## Shared AccessRequirements

- `profileReadRequirement` = ∩ `profile:read`
- `profileUpdateRequirement` = ∩ `profile:update`
- `settingsFacilityAdminRequirement` = ∩ `facility:admin` (documented create/delete; mostly **not mounted**)
- `settingsAdminAnyPermissions` = `facility:admin` ∪ `tenant:admin` ∪ `platform:admin`
- Admin navigate: `RouteAccessCatalog.setupEntry` / `subscriptionsEntry` / `accessAdminEntry`

## Product module labels

- `settingsAdministrationModuleLabel` / `settingsConfigurationModuleLabel` = `'settings / admin setup'`
