# Search and Filtering

## Scope
Defines how search fields, filters, sorting, and results states should behave.

## Mandatory rules
- Use shared search and select components where possible.
- Debounce remote search requests.
- Show loading, empty, error, and results states clearly.
- Keep search query, filters, and sort state explicit in the controller.
- Do not fetch unbounded data just to filter it in memory when a backend or database query is available.
- Preserve search/filter state when navigating back where the UX expects it.
- Localize result counts, empty states, and errors.

## Implementation standard
- Searchable selects should display a dropdown/menu overlay and should not push unrelated page content down by default.
- Filters should be resettable and visually clear.

## Acceptance checklist
- Search works on mobile and desktop.
- Empty search results are clear and helpful.
- Remote searches do not fire on every keystroke without debounce.

## Related rules
- [`reusable_components.md`](./reusable_components.md)
- [`forms.md`](./forms.md)
- [`pagination_data_tables.md`](./pagination_data_tables.md)
- [`performance.md`](./performance.md)
