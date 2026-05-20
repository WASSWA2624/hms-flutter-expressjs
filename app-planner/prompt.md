```text
Refactor and standardize the shared table component used across the HMS frontend.

Current implementation context:
- The shared table file is `frontend/lib/shared/components/app_list_table.dart`.
- It currently defines multiple table-related public widgets/classes, including `AppListTable`, `AppPaginatedListTable`, and `AppSearchablePaginatedListTable`.
- Screens such as Patients, Billing, Claims, OPD, Emergency, IPD, ICU, Nursing, Clinical, Lab, Radiology, Pharmacy, Discharge, and Theater currently use these table variants.
- The current desktop table headers use select-style column controls, as shown in the screenshots.

Goal:
Create one unified shared table component named `AppListTable` that handles all table use cases through configuration/properties instead of separate table widgets.

Requirements:
1. Keep only one public table widget class: `AppListTable`.
2. Fold the behavior of the existing table variants into `AppListTable`, including:
   - standard table display
   - paginated table display
   - responsive desktop/mobile display
3. On desktop and larger screens, display data as a clean table.
4. On small screens, display the same data as a compact, readable list.
5. Add a built-in search bar to `AppListTable`. through which search happens.
6. The search bar must include the advanced filter icon shown in the current UI.
7. Advanced filters must be configurable per table context.
8. Advanced filters must support date-based filtering where the table context requires date search.
9. Add a table settings / column visibility control near the search area.
10. The column visibility control must allow users to choose which columns are shown or hidden.
11. By default, show the numbering column plus the first 4–5 most important columns.
12. Add a numbering column to all table displays.
13. The numbering column must update based on the currently visible rows after search/filter changes.
14. Replace select-style table headers with simple text headers.
15. Each sortable header must behave like a text button with a sort icon.
16. Clicking a sortable header must toggle ascending and descending sorting.
17. Do not use `AppSelectField` or select-style controls inside table headers.
18. Keep the optional table title/description area compact.
19. Minimize vertical spacing so tables do not consume unnecessary space.
20. Preserve the current search text and search-field experience while table data updates.
21. Table data should update in real time from the current data source/state without disrupting the search bar.
22. Ensure the search bar and table controls remain usable on small screens.
23. Use the unified `AppListTable` across:
   - Patients
   - Billing
   - Claims
   - OPD
   - Emergency
   - IPD
   - ICU
   - Nursing
   - Clinical
   - Lab
   - Radiology
   - Pharmacy
   - Discharge
   - Theater
24. Also use the same `AppListTable` pattern for nested tables inside dialogs, modals, and screen-level detail components.
25. Keep the component flexible so columns, filters, sorting, pagination, responsive behavior, row actions, and display behavior are determined by properties passed to `AppListTable`.

Implementation expectations:
- Update `app_list_table.dart` to remove the need for separate public table variants.
- Replace current usages of `AppPaginatedListTable` and `AppSearchablePaginatedListTable` with `AppListTable`.
- Keep the implementation aligned with the existing Flutter theme, spacing, shared components, and responsive breakpoint system.
- Preserve existing screen behavior while standardizing the table UI and API.
- Do not introduce unrelated features or redesign unrelated parts of the app.
```

