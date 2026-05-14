# Performance Strategy

## Scope
Defines performance expectations for startup, rendering, lists, images, networking, and local data.

## Mandatory rules
- Avoid unnecessary rebuilds by keeping provider watches focused.
- Use `const` widgets where possible.
- Paginate or virtualize large lists and tables.
- Avoid loading huge datasets into memory.
- Use image sizes appropriate to their display context.
- Avoid heavy synchronous work on the UI thread.
- Cache thoughtfully and invalidate explicitly.
- Keep startup work minimal and visible through a startup state when needed.
- Use release/profile builds for meaningful performance checks.

## UI performance rules
- Split large pages into focused widgets.
- Use slivers or builders for long lists.
- Avoid expensive layout nesting when a simpler layout works.
- Apply max-width constraints on large screens for readability and layout stability.

## Acceptance checklist
- Common screens scroll smoothly on target devices.
- App startup is not blocked by unnecessary network calls.
- Large lists are paginated, streamed, or built lazily.

## Related rules
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`database_strategy.md`](./database_strategy.md)
- [`network_api.md`](./network_api.md)
- [`scalability.md`](./scalability.md)
