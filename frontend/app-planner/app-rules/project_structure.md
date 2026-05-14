# Project Structure

## Scope
Defines the canonical Flutter project structure. Every generated app must use this structure unless an app-specific rule intentionally extends it.

## Root structure
```txt
.
|-- .github/
|   `-- workflows/
|-- app-planner/
|   |-- app-rules/
|   `-- dev-plan/
|-- analysis_options.yaml
|-- l10n.yaml
|-- pubspec.yaml
|-- README.md
|-- assets/
|   |-- icons/
|   |-- images/
|   |-- illustrations/
|   `-- logos/
|-- docs/
|   |-- architecture/
|   |-- decisions/
|   |-- release/
|   |-- setup/
|   `-- workflows/
|-- env/
|   |-- development.json.example
|   |-- staging.json.example
|   `-- production.json.example
|-- lib/
|-- test/
|-- integration_test/
`-- tool/
```

`app-planner/` is documentation and must not be imported by application source code.

## `lib` structure
```txt
lib/
|-- main.dart
|-- bootstrap.dart
|-- app/
|   |-- app.dart
|   |-- locale/
|   |   `-- app_locale_controller.dart
|   |-- router/
|   |   |-- app_router.dart
|   |   |-- app_routes.dart
|   |   |-- route_guards.dart
|   |   |-- route_refresh_listenable.dart
|   |   |-- route_status_pages.dart
|   |   |-- url_strategy.dart
|   |   |-- url_strategy_stub.dart
|   |   `-- url_strategy_web.dart
|   |-- startup/
|   |   |-- app_preferences_restorer.dart
|   |   |-- app_startup_initializer.dart
|   |   |-- app_startup_state.dart
|   |   |-- startup_providers.dart
|   |   `-- startup_shell.dart
|   `-- theme/
|       |-- app_theme.dart
|       |-- app_theme_extensions.dart
|       `-- app_theme_mode_controller.dart
|-- core/
|   |-- config/
|   |-- errors/
|   |-- logging/
|   |-- network/
|   |-- permissions/
|   |-- responsive/
|   |-- security/
|   |-- storage/
|   |-- sync/
|   `-- utils/
|-- features/
|   `-- <feature_name>/
|       |-- data/
|       |   |-- datasources/
|       |   |-- dtos/
|       |   |-- mappers/
|       |   `-- repositories/
|       |-- domain/
|       |   |-- entities/
|       |   |-- repositories/
|       |   |-- services/
|       |   `-- usecases/
|       `-- presentation/
|           |-- controllers/
|           |-- pages/
|           |-- state/
|           `-- widgets/
|-- l10n/
|   |-- app_en.arb
|   |-- app_localizations.dart
|   |-- app_localizations_en.dart
|   `-- app_localizations_x.dart
`-- shared/
    |-- components/
    |-- data/
    |-- forms/
    |-- layout/
    |   |-- layout.dart
    |   |-- responsive_page.dart
    |   |-- responsive_shell_scaffold.dart
    |   `-- responsive_spacing.dart
    |-- search/
    `-- widgets/
```

## Required starter files
| File | Responsibility |
|---|---|
| `lib/main.dart` | Small entry point only. |
| `lib/bootstrap.dart` | Flutter binding initialization and root app launch. |
| `lib/app/app.dart` | `MaterialApp.router`, theme, localization, and app-level providers. |
| `lib/app/router/app_router.dart` | Central `go_router` configuration. |
| `lib/app/router/app_routes.dart` | Route names and paths. |
| `lib/app/router/route_guards.dart` | Route access and startup/session guard decisions. |
| `lib/app/theme/app_theme.dart` | Light and dark Material themes. |
| `lib/app/theme/app_theme_extensions.dart` | Shared spacing, radius, sizing, and status theme extensions. |
| `lib/app/theme/app_theme_mode_controller.dart` | Reactive theme-mode state. |
| `lib/core/responsive/app_breakpoints.dart` | Canonical breakpoints and layout helpers. |
| `lib/shared/layout/responsive_shell_scaffold.dart` | Mobile/tablet/desktop shell composition, desktop menu bar, and collapsible side navigation. |
| `lib/shared/layout/responsive_page.dart` | Page padding and max-width constraints. |
| `lib/shared/layout/responsive_spacing.dart` | Breakpoint-aware spacing helpers. |

## Mandatory rules
- Use `features/<feature_name>` for product behavior and screens.
- Use `core` only for cross-cutting infrastructure used by multiple features.
- Use `shared` only for reusable UI, state views, layout pieces, data helpers, search helpers, and form patterns that are not tied to one feature.
- Do not place feature-specific business logic in `core` or `shared`.
- Do not create a second folder or file for the same responsibility.
- Keep generated files beside their source files when Dart tooling expects it.
- Keep tests in folders that mirror the source structure.
- Keep root configuration files at the root: `pubspec.yaml`, `analysis_options.yaml`, and `l10n.yaml`.

## Acceptance checklist
- A new developer can locate startup, routes, theme, localization, responsive layout, networking, storage, and features quickly.
- No feature imports implementation details from another feature.
- No widget calls an API client, database, secure storage, or sync service directly.
- `README.md` explains the structure at a high level.

## Related rules
- [`architecture.md`](./architecture.md)
- [`coding_conventions.md`](./coding_conventions.md)
- [`feature_workflow.md`](./feature_workflow.md)
- [`testing.md`](./testing.md)
