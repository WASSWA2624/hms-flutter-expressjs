Under **Pay & Compensation**, remove the **Current Pay & Compensation** and **Pay Lines** sections and replace the entire content with a **AppListTable** component.

The table should include:

* A **search bar** with **Filter**, **Settings**, **Export** and **Add Pay Line** buttons.
* The table displaying all pay lines currently configured for the staff member.
* An **Actions** column with **Edit** and **Delete** options.
* Prevent the same pay line from being added more than once.

When **Add Pay Line** is clicked, open the pay-line form in a nested dialog, maximized by default.

Also remove the **Add Pay & Compensation** button from the footer, as it is no longer needed.
