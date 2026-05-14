# Performance and Scalability

This template keeps performance decisions generic so product features can scale
without rewriting app-wide foundations.

Rule sources:

- [`app-rules/performance.md`](../../app-planner/app-rules/performance.md)
- [`app-rules/scalability.md`](../../app-planner/app-rules/scalability.md)
- [`app-rules/responsive_adaptive_design.md`](../../app-planner/app-rules/responsive_adaptive_design.md)
- [`app-rules/pagination_data_tables.md`](../../app-planner/app-rules/pagination_data_tables.md)

## Provider Rebuilds

- Watch the narrowest Riverpod value a widget or provider needs. Prefer
  `select` for app-wide state such as startup, session, permissions, and theme
  values.
- Read dependencies inside callbacks with `ref.read` so user actions do not
  subscribe the widget to unrelated changes.
- Keep route refreshes tied to route-relevant auth state, such as session status
  and permission grants, instead of refreshing on every session object update.
- Place providers close to the layer they create. Feature controllers belong in
  feature presentation code, repositories belong in feature data code, and shared
  infrastructure belongs in `core`.
- Use `ref.read` inside callbacks such as navigation, refresh, and save actions
  unless the widget needs to rebuild when that dependency changes.

## Lists and Tables

- Use `AppDataList` for responsive list and table views. Mobile rows are built
  with lazy `ListView` builders.
- Use `AppPaginatedDataList` when a screen can display many records. Fetch or
  derive one `AppPage<T>` at a time and pass only that page into the component.
- Keep table rows keyed with `itemKeyBuilder` when rows can update, reorder, or
  be selected.
- Do not pass a whole remote table or large local query result into a widget.
  Repositories should accept `AppPageRequest` values and translate them to API
  query parameters, Drift limits, or indexed local reads.
- On small screens, prefer readable list rows with the same data meaning instead
  of forcing dense horizontal tables.

## Startup Work

- Startup may validate public config, initialize logging, restore preferences,
  create storage clients, and restore a local session.
- Startup must not block on feature data fetches, dashboard loads, large local
  scans, or nonessential network calls.
- Expensive feature preparation should happen after the app shell is visible and
  should expose loading, empty, and error states through feature controllers.

## Shared Component Growth

- Keep shared components feature-neutral. Shared APIs may accept builders,
  labels, state objects, and callbacks, but they must not know product domains.
- Prefer composition over new component families. Extend an existing generic
  component only when the behavior is common across features.
- Keep user-facing labels supplied by callers so localization stays in feature
  or app presentation code.

## Release Readiness Checklist

- Run `flutter analyze` and `flutter test` before release.
- Run key flows in profile or release mode on the lowest target device class.
- Confirm startup reaches the first visible shell without feature network calls.
- Confirm long lists use lazy builders, pagination, streams, or indexed local
  queries.
- Confirm paginated screens preserve page request state where refresh behavior
  requires it.
- Inspect provider watches in new screens for broad app-state subscriptions.
- Check desktop and mobile breakpoints for list readability and stable max-width
  behavior.
- Verify images are requested or resized near their display dimensions.
- Review shared components for product-specific fields before merging.

## Scalability Review Checklist

- New features can be added under `lib/features/<feature_name>` without changing
  unrelated feature folders.
- Feature repositories expose contracts that can page, stream, or query data
  instead of returning unbounded collections.
- Large result screens keep search, filters, sort, and `AppPageRequest` in
  explicit controller state.
- Shared widgets stay domain-neutral and accept builders, labels, callbacks, and
  typed state rather than product-specific fields.
- Route and shell changes remain centralized so adding screens does not require
  copied layouts.
- Startup work remains limited to app prerequisites; feature data loads after
  the shell is visible.
