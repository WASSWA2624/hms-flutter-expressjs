# 16 - Forms, Validation, Search, and Data Displays
Provide testable input and scalable data-display patterns across screen sizes.

## Applicable Rules
You must follow [`00-execution-policy.md`](./00-execution-policy.md), [`ui-patterns.mdc`](../.cursor/ui-patterns.mdc), [`validation.mdc`](../.cursor/validation.mdc), and [`components.mdc`](../.cursor/components.mdc).

## Implementation
1. Put reusable validators under `lib/shared/forms/` and product-specific validators with their features.
2. Form fields must preserve recoverable input.
3. Searchable selects should use suitable overlay or menu patterns.
4. Search and filter controllers must expose explicit state.
5. Provide mobile list and desktop table patterns.
6. Large datasets must use pagination or lazy loading.
7. Add tests for validators and important form components.

## Acceptance Criteria
- Recoverable form input must survive validation failures.
- Search and filters must remain explicit in state.
- Large datasets must not load unnecessarily.
- Validation utilities, state examples, and responsive displays must be available; searchable select may be added when needed.
