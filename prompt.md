To further standardize all tables across screens, implement the following unified structure and behavior:

1. Every table must include a global search bar, allowing users to search across all columns (both visible and hidden). This search bar should also contain:
   - A filter button: Opens an advanced filter modal where users can apply specific filtering criteria.
   - A settings button: Opens a dialog to select which columns are visible. User preferences for column visibility should persist for the session, so when a user returns, their column selections are remembered.

2. Each table column should display only a single data field—avoid combining multiple parameters (e.g., don’t display both name and ID in a single column). Each column must be unique.

3. Limit the table to five columns:
   - The leftmost column is the row number.
   - If the entity includes status and next-step actions:
     - The last column should be “Next Step,” containing an explicit action button. Clicking this button either opens a contextual dialog for the action or navigates the user directly to the relevant resource or screen.
     - The second-last column displays the current status with a clear, unambiguous label.

4. Ensure all statuses and actions in the tables and screens are explicit and clearly labeled. Users should always know both the current status and the next required action without guessing or unnecessary navigation.

5. Clicking any row (or “hero” area) in the table should open a modal dialog showing detailed information relevant to that entry, with clear actions available in the dialog for follow-up.

6. For the three main columns after the number column, prioritize and display the three most important, context-relevant data fields. If more detail is required in a single column, display the primary value prominently and any secondary information in a smaller, less prominent style (smaller font, unbolded), to visually signal its lower importance.

7. Tables must be responsive and maintain usability across different screen sizes.

8. Where possible, reuse existing shared components (from the shared folder) for consistency and efficiency. Ensure all data is mapped correctly to its respective column throughout.

Apply these standards to all screens utilizing tables to achieve a consistent, user-friendly, and actionable interface.