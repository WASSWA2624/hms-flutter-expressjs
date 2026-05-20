## Review the entire codebase and fully implement the following:

Focus on the frontend shared UI system and the module/workspace screens.

1. **Audit and reorganize `frontend/lib/shared`**
  - Review all shared components, layouts, forms, actions, dialogs, data helpers, and widgets.
  - Make sure each shared component is placed in the most appropriate shared folder.
  - Rename components only where the current name is unclear or not informative.
  - Remove or merge true duplicate components that perform the same UI responsibility.
  - Keep each shared component focused on one distinct UI purpose.
  - Do not place feature-specific business logic inside shared components.
  - Update imports and barrel exports after any reorganization.
2. **Reuse the existing shared UI foundation**
  - Reuse and extend the current shared components where appropriate, especially:
    - `AppWorkspace`
    - `AppWorkspaceHeader`
    - `AppWorkspaceSummaryCard`
    - `AppWorkspaceFilterBar`
    - `AppListTable`
    - `AppSearchBar`
    - `AppSelectField.searchable`
    - `AppDialog`
    - `AppButton`
    - `AppIconButton`
    - `AppLogo`
  - Do not create parallel components for the same layout, button, dialog, search, table, or badge behavior.
3. **Standardize the module/workspace page layout**
  Apply the same page structure to these screens:
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
   Do not include Settings in this update.
   Each screen should use the shared base workspace/page component and follow this visible structure:
  - A top header with the page title and appropriate logo on the left.
  - Action buttons aligned to the far right.
  - On large screens, action buttons should show both icon and label.
  - Below the header, show the notification/summary badges or cards.
  - Below the badges, show one consistent search bar.
  - Below the search bar, show the table.
4. **Make the search and table area uniform**
  - Use the same shared search bar styling and behavior across all target screens.
  - The search area should remain clean and should not include unrelated visible controls around it.
  - Tables should show no more than five visible columns at a time.
  - The table column-header selector should use the existing searchable select pattern so users can search and choose column headers.
  - Prevent duplicate visible columns in the table.
  - Keep table headers, rows, empty states, loading states, and row selection behavior consistent through shared components.
5. **Standardize badge, button, and modal behavior**
  - Top action buttons and notification/summary badges/cards should open their corresponding modal dialogs when clicked.
  - Reuse existing shared modal/dialog components wherever possible.
  - If a dialog already exists in shared components, reuse it instead of redefining a similar one.
  - Keep modal styling, buttons, spacing, titles, and actions uniform across the app.
6. **Clean up inconsistent page content**
  - Remove duplicated, unrelated, or mismatched visible section titles from the initial screen layout.
  - Avoid screens showing inconsistent headings such as a registry title where the current module requires a different page title.
  - Keep the initial page layout focused on: header, action buttons, summary badges, search bar, and table.
7. **Follow existing project rules**
  - Follow the app rules in `app-planner`.
  - Preserve existing localization, permissions, routing, controllers, and data flow.
  - Do not introduce new features beyond this UI modularization and uniformity work.
  - Keep the app compiling and passing the existing frontend validation checks.

