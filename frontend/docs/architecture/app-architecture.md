# App Architecture

This template follows feature-first clean architecture.

Rule sources:

- [`architecture.mdc`](../../.cursor/architecture.mdc)
- [`project_structure.mdc`](../../.cursor/project_structure.mdc)
- [`state_management.mdc`](../../.cursor/state_management.mdc)
- [`data_modeling.mdc`](../../.cursor/data_modeling.mdc)
- [`navigation.mdc`](../../.cursor/navigation.mdc)
- [`localization_i18n.mdc`](../../.cursor/localization_i18n.mdc)
- [`testing.mdc`](../../.cursor/testing.mdc)
- [`code_generation.mdc`](../../.cursor/code_generation.mdc)

## Dependency Direction

Dependencies flow inward through feature layers:

```txt
presentation -> domain <- data
data -> core infrastructure
app -> features and shared UI
```

The presentation layer owns pages, widgets, controllers, and UI state. It may
depend on domain contracts and entities, but it must not call APIs, databases,
secure storage, or platform services directly.

The domain layer owns entities, value objects, repository contracts, services,
and use cases. Domain code must stay independent of Flutter widgets, generated
database tables, API DTOs, and platform clients.

The data layer owns repository implementations, DTOs, mappers, and data sources.
It may depend on domain contracts and `core` infrastructure, but it must not
show UI, navigate, or expose raw external models to widgets.

The `core` folder owns cross-cutting infrastructure used by multiple features.
It must not contain feature-specific business rules.

The `shared` folder owns reusable, feature-neutral UI components and layouts. It
must not contain domain decisions.

## Canonical Library Structure

```txt
lib/
|-- main.dart
|-- bootstrap.dart
|-- app/
|   |-- app.dart
|   |-- router/
|   |-- startup/
|   `-- theme/
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
|   `-- home/
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
`-- shared/
    |-- actions/
    |-- components/
    |-- data/
    |-- forms/
    |-- layout/
    |-- opd_actions/
    |-- search/
    `-- reporting/
```

Feature modules under `lib/features/` own domain workflows. Shared pagination
models, search/filter controllers, permission-aware actions, patient details,
workflow steppers, and OPD/front-desk dialogs live under `shared` because they
are reused across modules.

## Provider Placement

Riverpod is the template's state management and dependency injection boundary.
Providers should live close to the layer they create:

| Provider type | Location |
|---|---|
| App configuration, startup, routing, theme | `lib/app/` or `lib/core/config/` |
| Shared infrastructure clients | `lib/core/network`, `lib/core/storage`, `lib/core/sync` |
| Feature repository implementations | `features/<feature>/data/repositories` |
| Feature controllers and UI state | `features/<feature>/presentation/controllers` and `presentation/state` |

Widgets should read controllers or UI state from providers. They should not
instantiate repositories, clients, databases, or storage services.

## Routing

Routing is centralized in `lib/app/router` with GoRouter. Route names and paths
belong in `app_routes.dart`; route construction belongs in `app_router.dart`;
guard rules belong in `route_guards.dart`.

Feature pages should be imported by the router, but features should not
navigate by hard-coded strings. Add route metadata before wiring protected or
permission-gated pages so guards can make decisions from typed route data.

## Localization

User-facing strings belong in `lib/l10n/app_en.arb` and are accessed through
the generated localization API and `app_localizations_x.dart`. Widgets,
controllers, validators, and shared components must not hard-code user-facing
copy.

Locale-aware dates, numbers, currencies, and plural text should use shared
formatting utilities from `lib/core/utils` or generated localization helpers.

## Testing

Tests mirror the source structure where practical:

```txt
test/
|-- app/
|-- core/
|-- features/
|-- l10n/
`-- shared/
integration_test/
```

Use unit tests for entities, value objects, mappers, validators, repositories,
and controller logic. Use widget tests for pages, shared components, forms, and
responsive layout. Use integration tests for startup, routing, and
platform-critical smoke flows. Tests should use provider overrides or mocks and
must not depend on production services or secrets.

## Code Generation

Generated Dart files stay beside their source files when required by Flutter,
Riverpod, Drift, Freezed, or JSON serialization tooling. Run generation before
analysis, tests, and release builds:

```sh
dart run build_runner build --delete-conflicting-outputs
```

Do not manually edit generated files. If generated output changes, commit both
the source file and generated file together.

## Cross-Cutting Consistency

All features must reuse shared infrastructure before creating module-specific
implementations. Apply in priority order:

1. Shared implementation from `lib/shared/` or `lib/core/`
2. Extension of an existing shared implementation
3. New module-specific code only when behavior is genuinely domain-specific

### Error and State Handling

- Use `AppFailure` (from `core/errors/app_failure.dart`) for all typed errors.
- Use `Result<T>` (from `core/errors/result.dart`) for repository return types.
- Use `AsyncStateScaffold` for top-level page state (loading, empty, error).
- Use `AppFailureStateView` or `AppFormInformationBanner.failure` inline.
- Use `showAppFailureSnackBar` (from `shared/layout/`) for transient feedback.
- Use `NetworkFailureMapper` to convert HTTP/Dio errors to typed failures.
- Use `ValidationMessagePresenter` for localized field-level error messages.

### Display Formatting

- Use `AppDisplay.apiLabel` to convert snake_case/kebab-case API values to
  human-readable labels. Do not create private formatting functions.
- Use `AppFormatters` for locale-aware dates, times, numbers, and currencies.
- Use `AppDisplay.joinNonEmpty` for multi-value display labels.

### Mutation and Sync

- Controllers write through repositories over HTTP; WebSockets are never
  a mutation transport.
- On success, patch Riverpod state immediately from the response.
- On cancel/failure, UI state remains unchanged.
- Use `AppActionRunner` for idempotent, retryable mutations.
- Use `createIdempotencyKey` for offline-capable writes.

## Boundary Checklist

- Widgets do not call APIs, databases, secure storage, or platform services.
- Domain entities and use cases do not import Flutter UI packages.
- DTOs and database models are mapped before reaching domain or presentation.
- Repository implementations coordinate data sources and return domain models.
- `core` contains reusable infrastructure only.
- `shared` contains reusable UI only.
- Features expose intentional entry points and do not import implementation
  details from other features.
- New features follow `docs/workflows/feature-workflow.md`.
