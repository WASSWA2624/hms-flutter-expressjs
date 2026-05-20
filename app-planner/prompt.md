You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and screenshots. Align the changes with the existing implementation and UI patterns. The frontend currently uses shared workspace, search, table, dialog, button, and status components. Reuse or extend shared components where possible instead of duplicating page-specific logic.

Goal:
Standardize the listed workspace pages by adding missing table settings controls, enabling requested ascending/descending table-header sorting, expanding selected worklists to the full page width, moving selected-record detail panels into modal dialogs, and removing the specified extra sections.

General instructions:
- Keep existing behavior unless a change is explicitly listed below.
- Use existing shared components such as AppWorkspace, AppWorkspaceFilterBar, AppSearchBar, AppListTable, AppListTableColumn, AppDialog/showAppDialog, AppButton, AppIconButton, and existing status/detail widgets where applicable.
- Move reusable changes into shared components when the same behavior is needed across multiple pages.
- Do not change the Clinical workspace.
- Do not change the Setup workspace except for the one specified section removal.

Page-specific changes:

1. Patients page
- Add the table settings button beside the existing advanced filter control in the search bar.
- Add ascending/descending sorting on the table column headers.

2. Billing page
- Add the table settings button beside the advanced filter control in the search bar.
- Make the billing worklist/table span the full available page width.
- Remove the right-side Invoice detail panel.
- Show invoice/billing item details in a modal dialog when a billing row is selected.
- Remove the Cashier close section from the main body.
- Move the Close shift and Close day actions into the page header.
- When Close shift or Close day is clicked, open the existing relevant modal/dialog for that action.

3. Claims page
- Add the table settings button beside the advanced filter control in the search bar.
- Make the Claims worklist span the full available page width.
- Remove the right-side Claim detail panel.
- Show claim details in a modal dialog when a claim row is selected.
- Remove the backend gaps section from the page.

4. OPD page
- Add ascending/descending sorting on the OPD table column headers.

5. Emergency page
- Add the table settings button beside the advanced filter control in the search bar.
- Make the Emergency board table span the full available page width.
- Remove the right-side selected-case/no-case panel.
- Show selected emergency case details in a modal dialog.
- Add ascending/descending sorting on the table column headers.

6. IPD page
- Add the table settings button beside the advanced filter control in the search bar.
- Make the Inpatient board table span the full available page width.
- Move the admission detail/selected admission view into a modal dialog opened from row selection.

7. ICU page
- Make the ICU board table span the full available page width.
- Move the selected ICU patient/stay detail view into a modal dialog opened from row selection.

8. Nursing page
- Keep the current layout.
- Add ascending/descending sorting on the table column headers.

9. Clinical page
- Leave the Clinical workspace unchanged.

10. Lab page
- Make the Lab queue table span the full available page width.
- Move Lab detail into a modal dialog opened from row selection.
- Add the table settings button beside the filter control in the search bar.
- Remove the Catalog and QC section from the page.

11. Radiology page
- Add the table settings button beside the filter control in the search bar.
- Make the Imaging worklist span the full available page width.
- Move the Radiology workflow/detail view into a modal dialog opened from row selection.
- Remove the backend gaps section from the page.
- Deduplicate the Refresh catalog and Refresh buttons so only one refresh action remains.

12. Pharmacy page
- Add the table settings button beside the filter control in the search bar.
- Make the Order queue span the full available page width.
- Add ascending/descending sorting on the order queue table column headers.
- Move the prescription/detail section into a modal dialog opened from row selection.
- Remove the Formulary and Stock section from the main page.
- Move Formulary/Stock access to a simple header button that opens it in a nested screen/view.

13. Discharge page
- Add the table settings button beside the filter control in the search bar.
- Make the Discharge worklist span the full available page width.
- Move the discharge detail view into a modal dialog opened from row selection.
- Remove the backend gaps section from the page.

14. Theater page
- Add the table settings button to the search bar.
- Make the Daily cases section span the full available page width.
- Move case detail into a modal dialog opened from row selection.

15. Settings page
- Add the settings icon beside the Settings page title on the left.
- Add a Refresh button in the page header.

16. Tenant and facility setup page
- Leave the page unchanged except for removing the section that says:
  “Prepare the organization and facility before daily hospital operations begin.”

Shared-component work:
- Use the existing table/search components for table settings instead of building separate page-specific settings buttons.
- Use the existing AppListTable sorting capability by adding sort comparators to the requested sortable columns.
- Reuse existing detail panel/body widgets inside dialogs where possible.
- Remove backend gaps sections wherever they are rendered by the affected workspace pages.