# 16 - Forms, validation, search, and data displays

## Goal
Implement form standards, validators, searchable selects, filtering, pagination, and list/table patterns.

## Applies app rules
- [`forms.md`](../app-rules/forms.md)
- [`validation.md`](../app-rules/validation.md)
- [`search_filtering.md`](../app-rules/search_filtering.md)
- [`pagination_data_tables.md`](../app-rules/pagination_data_tables.md)
- [`reusable_components.md`](../app-rules/reusable_components.md)

## Implementation tasks
1. Follow [`00-execution-policy.md`](./00-execution-policy.md).
2. Create reusable validators under `lib/shared/forms/` or feature-specific validators where rules are product-specific.
3. Create form field patterns that preserve recoverable input.
4. Create searchable select behavior using overlay/menu patterns where appropriate.
5. Create search/filter controller examples with explicit state.
6. Create mobile list and desktop table patterns for data displays.
7. Add pagination/lazy loading examples for large datasets.
8. Add tests for validation and important form components.

## Expected output
- Validation utilities.
- Search/filter state examples.
- Searchable select component when needed.
- Responsive list/table examples.

## Acceptance criteria
- Forms preserve recoverable input.
- Search and filters are explicit in state.
- Large datasets are not loaded unnecessarily.
