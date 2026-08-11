# Settings workspace UI inventory

Source: `tabs-lister/19-settings.md` · Code base date: 2026-08-11

## Context

Catalog of every visible / reachable UI atom on `SettingsPage`. Not a redesign. Findings traced from presentation code, access maps, routes, and tests—not a visual walkthrough.

Settings uses hybrid **`AppTabStrip` + single-expand accordion** deep-linked via `?tab=` (Account also `?panel=`). Each accordion section is inventoried as a tab-equivalent file.

**Workspace:** `/settings` (`AppRoutes.settings`)  
**Page:** `frontend/lib/features/settings/presentation/pages/settings_page.dart`  
**Access:** `frontend/lib/features/settings/presentation/settings_access.dart`  
**Query model:** `SettingsPageQuery`

## Accordion sections (order)

| `tab` id | File |
| --- | --- |
| `preferences` | [01-preferences.md](01-preferences.md) |
| `accessibility` | [02-accessibility.md](02-accessibility.md) |
| `account` | [03-account.md](03-account.md) |
| `leaves` | [04-leaves.md](04-leaves.md) |
| `rosters` | [05-rosters.md](05-rosters.md) |
| `administration` | [06-administration.md](06-administration.md) |
| `configuration` | [07-configuration.md](07-configuration.md) |
| `workspace` | [08-workspace.md](08-workspace.md) |

Default tab is `preferences` (omitted from URL when default). Account nested panels: `profile`, `change-password` via `?panel=`.

## Shared / cross-section chrome

See [00-shared-chrome.md](00-shared-chrome.md).

## Convention gaps

See [99-convention-gaps.md](99-convention-gaps.md).

## Source files

- `frontend/lib/features/settings/presentation/pages/settings_page.dart`
- `frontend/lib/features/settings/presentation/settings_access.dart`
- `frontend/lib/features/settings/presentation/controllers/settings_workspace_controller.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_preferences_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_accessibility_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_account_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_leaves_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_rosters_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_administration_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_configuration_section.dart`
- `frontend/lib/features/settings/presentation/widgets/settings_workspace_section.dart`
- `frontend/test/features/settings/`
