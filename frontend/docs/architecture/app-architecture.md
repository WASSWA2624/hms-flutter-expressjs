# App Architecture

This template follows feature-first clean architecture.

Rule sources:

- [`app-rules/architecture.md`](../../app-planner/app-rules/architecture.md)
- [`app-rules/project_structure.md`](../../app-planner/app-rules/project_structure.md)
- [`app-rules/state_management.md`](../../app-planner/app-rules/state_management.md)
- [`app-rules/data_modeling.md`](../../app-planner/app-rules/data_modeling.md)
- [`app-rules/navigation.md`](../../app-planner/app-rules/navigation.md)
- [`app-rules/localization_i18n.md`](../../app-planner/app-rules/localization_i18n.md)
- [`app-rules/testing.md`](../../app-planner/app-rules/testing.md)
- [`app-rules/code_generation.md`](../../app-planner/app-rules/code_generation.md)

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
    |-- components/
    |-- data/
    |-- forms/
    |-- layout/
    |-- search/
    `-- widgets/
```

The `home` feature is the starter example feature. Its folders are intentionally
minimal and demonstrate where production code belongs when the feature grows.
Shared pagination models and search/filter controllers live under `shared`
because they are feature-neutral UI/data helpers.

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
