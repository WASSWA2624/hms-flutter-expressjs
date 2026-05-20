Improve the current HMS frontend table and workspace UI polish while keeping the existing implementation structure.

Current implementation context:
- Shared table component: `frontend/lib/shared/components/app_list_table.dart`
- Shared search component: `frontend/lib/shared/components/app_search_bar.dart`
- Workspace layout/header/cards: `frontend/lib/shared/layout/app_workspace.dart`
- Shell/menu icons are defined in `frontend/lib/app/router/app_router.dart`
- The current `AppListTable` implementation already supports search, responsive table/list display, numbering, column visibility, and sorting state.
- The current workspace header still shows the app logo as the default title leading widget on many screens.
- Header status badges such as `Live`, `Live sync`, `Saving`, `Posting`, and similar labels are still shown beside some page titles.

Tasks:

1. Update the `AppListTable` column settings control
- Move the table column settings button into the search bar.
- Place it on the right side of the advanced filters button.
- Change the column settings icon to a cog/settings icon.
- Keep the column settings behavior the same: users should still be able to choose which columns are shown or hidden.
- Do not place the column settings button as a separate control outside the search bar.

2. Improve table headers and sorting
- Keep the current simple text-style table headers.
- Make the headers look cleaner and more polished.
- Ensure each sortable table header shows a visible sort affordance.
- Clicking a sortable header must toggle sorting between ascending and descending.
- Ensure the active sorted column visually indicates its current direction.
- Do not reintroduce select/dropdown-style column headers.

3. Improve responsive table behavior
- Keep desktop/tablet layouts as tables.
- Keep small-screen layouts as compact readable lists.
- Preserve the numbering column/list numbering behavior.
- Ensure numbering updates correctly after search, filtering, sorting, or data refresh.
- Keep the search field stable while table data updates.

4. Improve workspace summary/activity cards on small screens
- In `AppWorkspace` summary/activity items below the page header, keep the current full card layout on desktop.
- On small screens, show only the icon and the badge/count value.
- Move the badge/count value so it overlaps the icon halfway at the top-right corner.
- Keep the small-screen layout compact and easy to tap.

5. Replace title logo with screen-specific title icons
- Stop using the HMS app logo as the default title icon for module pages.
- Use the appropriate module icon beside each page title.
- Match the title icon to the corresponding sidebar/menu icon from `app_router.dart`.
- Apply this to screens such as:
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
  - Setup

6. Standardize workspace header action buttons
- Review all module screens and ensure header action buttons display consistently.
- On desktop and larger screens, action buttons should show both icon and label where the action has a label.
- On smaller screens, action buttons should display as icon-only buttons with proper tooltip/semantic labels.
- Fix screens where a header action currently shows only an icon on larger screens when it should show a label.
- Check examples such as Emergency registration and other module actions.

7. Remove page title status badges
- Remove header-level status badges beside page titles, including labels such as:
  - `Live`
  - `Live sync`
  - `Saving`
  - `Posting`
  - similar page-level status labels
- Apply this cleanup across screens such as Billing, Claims/Insurance, Emergency, and other modules where these badges appear beside the title.

Implementation expectations:
- Keep the existing HMS theme, spacing system, icons, and responsive breakpoint system.
- Make changes through shared components where possible instead of duplicating fixes in every screen.
- Update affected screens only as needed to use the improved shared behavior.
- Do not redesign unrelated parts of the app.
- Do not add new features beyond the requested table, search bar, workspace header, summary card, title icon, action button, and status badge improvements.