You are working on the HOSSPI Hospital Management System codebase.

Before implementing, review the current app-planner, backend, frontend, and latest screenshots. Align the changes with the existing implementation and UI patterns.

Goal:
Make the table areas more uniform by using the table’s built-in search toolbar where requested, and by adding missing table titles/descriptions where requested also ensure the ascending/descending functionalities exist on the column headers.

General instructions:
- Preserve existing behavior unless a change is explicitly listed below.
- Reuse existing shared table/search components instead of creating page-specific duplicate search bars.
- Where a page is changed to use the table’s built-in search bar, remove the separate standalone search bar above the table and pass the existing search configuration into the table component.
- Keep the existing search placeholder text, filter behavior, settings behavior, row selection behavior, dialogs, sorting, columns, summary cards, and header actions unless explicitly changed below.
- The built-in table search bar should appear inside the table/list section, directly above the table headers, matching the current Nursing and Clinical table pattern.
- Use the existing table title/description pattern for pages where a table title and description are requested.
- Do not change the Nursing page.

Page-specific changes:

1. Patients page
- Keep the current patient screen layout.
- Add a table title and brief table description above the patient table.
- Do not change the current patient search bar, advanced filter, table settings button, sorting, columns, or row behavior.

2. Billing page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Billing worklist/table section.
- Keep the existing advanced filter and table settings controls as part of the table search area.
- Keep the existing Billing worklist title and description.
- Do not change the current header actions, summary cards, columns, row behavior, or detail dialog behavior.

3. Claims page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Claims worklist section.
- The built-in table search bar must include the existing filter control and table settings button.
- Keep the existing Claims worklist title and description.
- Do not change the current header actions, summary cards, columns, row behavior, or detail dialog behavior.

4. OPD page
- Keep the current table search behavior.
- Add a table title and brief table description above the OPD table.
- Do not change the current search controls, sorting, columns, or row behavior.

5. Emergency page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Emergency board section.
- Keep the existing search controls currently used on the page.
- Keep the existing Emergency board title and description.
- Do not change the current summary cards, columns, sorting, row behavior, or detail dialog behavior.

6. IPD page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Inpatient board section.
- Keep the existing search controls currently used on the page.
- Keep the existing Inpatient board title and description.
- Do not change the current summary cards, columns, row behavior, empty state, or detail dialog behavior.

7. ICU page
- Replace the separate standalone search bar with the table’s built-in search bar inside the ICU board section.
- Keep the existing search controls currently used on the page.
- Keep the existing ICU board title and description.
- Do not change the current summary cards, columns, row behavior, empty state, or detail dialog behavior.

8. Nursing page
- Leave the Nursing page unchanged.

9. Clinical page
- Keep the current Clinical layout and table search behavior.
- Add a table title and brief table description above the Clinical table.
- Do not change the current search controls, columns, row selection, sorting, or row highlighting behavior.

10. Lab page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Lab queue section.
- Keep the existing search controls currently used on the page.
- Keep the existing Lab queue title and description.
- Do not change the current header actions, summary cards, columns, row behavior, or detail dialog behavior.

11. Radiology page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Imaging worklist section.
- Keep the existing search controls currently used on the page.
- Keep the existing Imaging worklist title and description.
- Do not change the current header actions, summary cards, columns, row behavior, or detail dialog behavior.

12. Pharmacy page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Order queue section.
- Keep the existing search controls currently used on the page.
- Keep the existing Order queue title and description.
- Do not change the current header actions, summary cards, columns, sorting, row behavior, or detail dialog behavior.

13. Discharge page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Discharge worklist section.
- Keep the existing search controls currently used on the page.
- Keep the existing Discharge worklist title and description.
- Do not change the current header actions, summary cards, columns, row behavior, or detail dialog behavior.

14. Theater page
- Replace the separate standalone search bar with the table’s built-in search bar inside the Daily cases section.
- Keep the existing search controls currently used on the page.
- Keep the existing Daily cases title and description.
- Do not change the current header actions, summary cards, columns, row behavior, empty state, or detail dialog behavior.

Shared-component guidance:
- Prefer configuring the existing table component with its built-in search, title, and description props instead of wrapping each table with separate search UI.
- Avoid duplicate search bars on any page changed in this prompt.
- Avoid duplicate filter/settings buttons after moving search into the table.
- Keep visual spacing and alignment consistent with the current Nursing and Clinical table sections.