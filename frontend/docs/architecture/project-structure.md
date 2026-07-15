# Project Structure

The template follows
[`project_structure.mdc`](../../.cursor/project_structure.mdc).

```txt
.
|-- analysis_options.yaml
|-- pubspec.yaml
|-- README.md
|-- docs/
|   |-- architecture/
|   |-- decisions/
|   |-- release/
|   |-- setup/
|   `-- workflows/
|-- assets/
|   |-- icons/
|   |-- images/
|   |-- illustrations/
|   `-- logos/
|-- lib/
|   |-- main.dart
|   |-- bootstrap.dart
|   |-- app/
|   |   |-- app.dart
|   |   |-- router/
|   |   |-- startup/
|   |   `-- theme/
|   |-- core/
|   |   |-- config/
|   |   |-- errors/
|   |   |-- logging/
|   |   |-- network/
|   |   |-- permissions/
|   |   |-- responsive/
|   |   |-- security/
|   |   |-- storage/
|   |   |-- sync/
|   |   `-- utils/
|   |-- features/
|   |   `-- <feature_name>/
|   |       |-- data/
|   |       |   |-- datasources/
|   |       |   |-- dtos/
|   |       |   |-- mappers/
|   |       |   `-- repositories/
|   |       |-- domain/
|   |       |   |-- entities/
|   |       |   |-- repositories/
|   |       |   |-- services/
|   |       |   `-- usecases/
|   |       `-- presentation/
|   |           |-- controllers/
|   |           |-- pages/
|   |           |-- state/
|   |           `-- widgets/
|   |-- l10n/
|   `-- shared/
|       |-- actions/
|       |-- components/
|       |-- data/
|       |-- forms/
|       |-- layout/
|       |-- opd_actions/
|       |-- search/
|       `-- reporting/
|-- test/
|   |-- app/
|   |-- core/
|   |-- features/
|   |-- l10n/
|   `-- shared/
|-- integration_test/
|-- tool/
|-- android/
|-- ios/
|-- web/
|-- windows/
|-- macos/
`-- linux/
```

Feature code is organized under `lib/features/<feature_name>/data`, `domain`,
and `presentation`. Production modules include `home`, `auth`, `patients`,
`opd`, `reception`, clinical workspaces, and related domains. Cross-cutting
infrastructure belongs in `lib/core`. Reusable, feature-neutral UI belongs in
`lib/shared` (`components`, `actions`, `opd_actions`, `layout`, `forms`,
`reporting`). Shared pagination helpers live in `shared/data` and search
helpers in `shared/search`. Shared product-neutral static assets belong in
`assets/` and should be grouped by asset type. Platform folders are generated
by Flutter and should stay limited to host-specific runner code and
configuration.

## Key Shared Utilities

| Location | Utility | Purpose |
|---|---|---|
| `core/errors/app_failure.dart` | `AppFailure` | Typed failure hierarchy for all error categories |
| `core/errors/result.dart` | `Result<T>` | Success/Failure result monad for repository returns |
| `core/errors/validation_message_presenter.dart` | `ValidationMessagePresenter` | Localized API validation error presentation |
| `core/network/network_failure_mapper.dart` | `NetworkFailureMapper` | Maps HTTP/Dio errors to typed `AppFailure` |
| `core/network/idempotency.dart` | `createIdempotencyKey` | UUID-based idempotency keys for mutations |
| `core/utils/app_display.dart` | `AppDisplay.apiLabel` | Converts snake_case/kebab-case to display labels |
| `core/utils/app_formatters.dart` | `AppFormatters` | Locale-aware date/time/number/currency formatting |
| `shared/components/app_state_view.dart` | `AsyncStateScaffold` | Unified async loading/empty/error/data rendering |
| `shared/components/app_form_information_banner.dart` | `AppFormInformationBanner` | Inline form-level failure feedback |
| `shared/layout/app_workspace_feedback.dart` | `showAppFailureSnackBar` | Transient failure snackbar for workspace pages |
| `shared/actions/app_action_lifecycle.dart` | `AppActionRunner` | Idempotent, retryable mutation lifecycle |
| `l10n/app_localizations_x.dart` | `AppFailureDisplay` | Extension for localized failure messages |

Tests mirror the source folders where practical. Keep unit tests for core
utilities, mappers, validators, repositories, and use cases in the matching
`test/` folder. Keep widget tests for pages and shared UI under the equivalent
presentation or shared UI path.

See `docs/architecture/app-architecture.md` for dependency direction, layer
boundaries, provider placement, routing, localization, testing, code generation,
and the starter feature skeleton. See `docs/workflows/feature-workflow.md` for
the repeatable process used when adding feature folders.
