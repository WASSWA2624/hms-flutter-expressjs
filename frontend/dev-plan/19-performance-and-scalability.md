# 19 - Performance and Scalability
Keep startup, rendering, shared UI, and future feature growth efficient.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`performance.mdc`](../.cursor/performance.mdc), [`scalability.mdc`](../.cursor/scalability.mdc), [`layouts.mdc`](../.cursor/layouts.mdc), and [`ui-patterns.mdc`](../.cursor/ui-patterns.mdc).

## Implementation
1. Review provider watches and remove unnecessary rebuilds.
2. Growing lists must be lazy, virtualized, or paginated.
3. Startup must not perform heavy network work.
4. Shell layout widgets should remain focused and reusable.
5. Shared components must remain generic and stable.
6. Document release performance checks and a scalability review checklist.

## Acceptance Criteria
- Large lists must remain performant.
- Startup must remain minimal.
- New features must not require unrelated rewrites.
- Performance notes and lazy or paginated list patterns must be available for release review.
