# Feature Workflow

Rule sources:

- [`app-rules/feature_workflow.md`](../../app-planner/app-rules/feature_workflow.md)
- [`app-rules/checklists.md`](../../app-planner/app-rules/checklists.md)
- [`app-rules/coding_conventions.md`](../../app-planner/app-rules/coding_conventions.md)
- [`app-rules/architecture.md`](../../app-planner/app-rules/architecture.md)
- [`app-rules/project_structure.md`](../../app-planner/app-rules/project_structure.md)
- [`app-rules/reusable_components.md`](../../app-planner/app-rules/reusable_components.md)
- [`app-rules/localization_i18n.md`](../../app-planner/app-rules/localization_i18n.md)
- [`app-rules/testing.md`](../../app-planner/app-rules/testing.md)

Use this workflow for every new feature added to the template or to an app
built from it. Keep changes small enough that each file has one clear
responsibility.

## 1. Define the Feature Boundary

Before creating files, identify:

- Route name, route path, and whether the route is public, protected, or
  permission-gated.
- Presentation state, loading, empty, error, and success behavior.
- Domain entities, value objects, repository contracts, and optional use cases.
- Data needs, including remote API, local cache, secure storage, preferences,
  offline queue, or platform service boundaries.
- Validation rules and where errors should be surfaced.
- Localization keys for all user-facing strings, accessibility labels, and
  validation messages.
- Supported breakpoints, input methods, and platform-specific behavior.
- Unit, widget, and integration test coverage.

Small presentational features may omit use cases, but must still keep UI,
domain contracts, and data access boundaries clear.

## 2. Create the Standard Folder Shape

Create feature files under:

```txt
lib/features/<feature_name>/
|-- data/
|   |-- datasources/
|   |-- dtos/
|   |-- mappers/
|   `-- repositories/
|-- domain/
|   |-- entities/
|   |-- repositories/
|   |-- services/
|   `-- usecases/
`-- presentation/
    |-- controllers/
    |-- pages/
    |-- state/
    `-- widgets/
```

Create the `data`, `domain`, and `presentation` layer folders for feature
implementations. Add the listed subfolders when their responsibility is needed,
and keep every file in the matching layer. Tests should mirror the source
structure under `test/features/<feature_name>/`.

## 3. Build Domain and Data Boundaries First

For non-trivial flows:

- Define typed domain entities and repository contracts before UI calls data.
- Keep DTOs and generated database rows in `data`.
- Add explicit mappers between DTOs, database rows, and domain entities.
- Make repository implementations coordinate data sources and return domain
  results.
- Keep API clients, Drift databases, secure storage, preferences, sync queues,
  and platform services out of widgets and controllers.

Use `core` infrastructure for shared clients and utilities. Do not place
feature-specific business rules in `core` or `shared`.

## 4. Add Presentation State and UI

Place controllers in `presentation/controllers` and state classes in
`presentation/state` when a dedicated state shape is needed. Widgets should read
controller or state providers and should not instantiate repositories or data
sources.

Use shared components from `lib/shared` before adding feature-specific widgets.
Feature widgets should be created only when the behavior is owned by that
feature. Keep page files focused on composition and layout.

## 5. Add Routing, Localization, and Responsive Behavior

- Add route metadata in `lib/app/router/app_routes.dart`.
- Add route construction in `lib/app/router/app_router.dart`.
- Add or update guard behavior in `lib/app/router/route_guards.dart` when the
  feature is protected or permission-gated.
- Add localization keys to `lib/l10n/app_en.arb` before using text in widgets.
- Use generated localization accessors instead of hard-coded user-facing text.
- Validate desktop, tablet, and phone layouts with existing responsive helpers.
- Support keyboard, mouse, touch, accessibility labels, and platform safe areas
  where relevant.

## 6. Test the Feature

Add focused tests for:

- Controller state transitions and user actions.
- Repository mapping and failure handling.
- DTO, database, and mapper behavior when data is transformed.
- Validators and value objects.
- Important widgets, forms, empty states, errors, loading states, and responsive
  layout.
- Startup, routing, or platform-critical behavior through integration tests
  when the feature changes those flows.

Use provider overrides or mocks. Tests must not require real production
services, secrets, or credentials.

## 7. Update Documentation and Decisions

Update docs when the feature changes app structure, workflow, dependencies,
architecture boundaries, setup commands, release behavior, or shared component
contracts.

Create an ADR from `docs/decisions/0000-template.md` for major dependency,
architecture, security, storage, offline, routing, platform, or workflow
decisions.

## 8. Run the Quality Gate

Run this before review:

```sh
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test
```

Use focused tests while developing, then run the full gate before opening a
pull request or merging.

## Review Checklist

- Feature folder follows the standard structure.
- User-facing strings are localized.
- UI uses theme tokens and shared components.
- Loading, empty, error, and success states are handled.
- Forms validate and preserve recoverable input.
- Data models are mapped explicitly.
- Tests cover controller and critical UI behavior.
- Docs and ADRs are updated when conventions or decisions change.
