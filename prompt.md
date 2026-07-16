The goal is to standardize all patient encounter flow dialogs to ensure maximum uniformity and clarity across the user experience. This implementation applies strictly to the dialogues listed in the [patient encounter flow](/dialog-inventory/02-patient-encounter-flow.md) file, found in the [Dialog Inventory](/dialog-inventory/) folder. The following guidelines must be followed:

1. **Footer Actions & Buttons**  
   - Every dialog must have a consistent footer built using the shared footer or button group components from the shared folder.
   - Action buttons must always use the established reusable button components from the shared directory, each with the appropriate color-coded icons (for example, red for Delete, green for Create, yellow or blue for Edit, grey for Cancel, etc.), consistent with existing UI patterns.
   - Place a "Cancel" button at the far right of the footer; always label it "Cancel" (not "Close") and ensure it aborts the current action. Use the standard Cancel button component with its associated icon.
   - If the dialog supports CRUD actions (Create, Read, Edit, Delete), display their respective buttons—each using its shared component and color/icon—immediately to the left of the Cancel button in this order: Create, Read, Edit (not Update), Delete. Only include the actions actually supported by the dialog.
   - For actions that require user confirmation, add a "Confirm" button, making sure there are no duplicate actions, and also use its dedicated shared component with an appropriate color/icon.
   - All other dialog-specific buttons must be placed to the left of these standard CRUD actions, and must use the shared button or action group components, including relevant icons and color coding.

2. **Titles**  
   - Dialog titles must use a general and descriptive naming convention, not specific or personalized names. For instance, prefer "User Details Dialog" rather than a patient’s name. Use "OPD Flow" for Outpatient Department Flow, rather than an encounter-specific name. Title styling should use the standardized dialog header component from the shared folder, where available.

3. **Loading and State Management**  
   - Whenever a dialog performs an action (such as backend data updates), display a loading spinner using the shared loading component, including appropriate contextual text.
   - While loading is in progress, ensure the indicator is non-dismissible until the action is fully complete.
   - Dialogs must update their internal state in real time to reflect backend changes, ensuring all affected data in the UI remains current across the application.

4. **Component Reuse**  
   - All possible dialog sections must be built using, or replaced by, the existing reusable components from the shared folder—such as patient details, action groups, status indicators, etc. Reuse is mandatory; do not duplicate logic or UI already provided by shared components.

5. **Behavior and Responsiveness**  
   - Dialogs must load and display the relevant context-specific data immediately, with any user-perceived delays only caused by network requests—not by inefficient code or suboptimal use of reusable components.
   - Dialog behavior must always match its stated purpose (e.g., a patient details dialog reliably loads the correct data for its context and keeps it up to date as needed).

By rigorously following these principles and ensuring all buttons use proper color-coded icons from shared components, all patient encounter dialogs will present a consistent, professional, and highly usable interface aligned across the application.