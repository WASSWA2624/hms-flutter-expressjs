# Pagination, Lists, and Data Tables

## Scope
Defines scalable data display for lists, table-like rows, grids, and paginated views.

## Mandatory rules
- Use lazy builders for long lists.
- Use pagination, infinite loading, or server-side queries for large datasets.
- Do not load large tables into memory unnecessarily.
- Keep row tap/click behavior clear and accessible.
- Use responsive alternatives for dense tables on small screens.
- Keep column labels clear and localized.
- Use stable item keys when rows can update or reorder.

## Implementation standard
- On mobile, dense tables may become list rows/cards with the same data meaning.
- On desktop, data-heavy screens may use wider containers and horizontal overflow only when necessary.

## Acceptance checklist
- Large datasets remain performant.
- Rows are readable at small and large screen sizes.
- Pagination state survives refresh where needed.

## Related rules
- [`responsive_adaptive_design.md`](./responsive_adaptive_design.md)
- [`search_filtering.md`](./search_filtering.md)
- [`performance.md`](./performance.md)
- [`accessibility.md`](./accessibility.md)
