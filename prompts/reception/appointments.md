Refine the appointments tab button and related action buttons on the `/reception` screen as follows:

- The "Appointments" action is presented as a tab button in the main reception screen. When selected, it should:
  - Display the appointments section with a table or list showing all current, scheduled, and due appointments in real time, always in sync with the backend data.
  - Update the URL to reflect that the user is viewing appointments.
  - Allow scheduling new appointments via a clearly visible primary action button, accessible when this tab is active.

- The following action buttons should always be visible in the respective toolbar area regardless of the selected tab:
  - **Register Patient**
  - **Refresh**
  - **Full Registry** (under Appointments)
  - **Full OPD** (under Desk Queue, Active Visits, and Payment Gate)

- Each tab (Appointments, Desk Queue, Active Visits, Payment Gate) should display its main list and maintain a consistent toolbar that always shows the core actions above; only the specialized or context-specific primary button for the tab (e.g., billing in Payment Gate) should change.

- Whenever a tab-specific button is not relevant (i.e., not active or not allowed for the current tab/context), make it visibly inactive (disabled) and add a tooltip explaining why it is disabled and under what conditions it becomes active.

- Ensure users can always register patients and refresh the data regardless of tab, and that creating appointments is clearly accessible when viewing appointments.

- All updates to UI state, such as which action is enabled, disabled, or shows a tooltip, should occur in real time and remain synchronized with the current backend state and user permissions.
