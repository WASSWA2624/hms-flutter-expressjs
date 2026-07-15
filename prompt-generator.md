{screen_name}

This is a prompt generator for standardizing existing screens in our application. 

**Purpose:**  
Given the name of a screen you want to standardize, this generator will produce a clear, actionable prompt to refactor the screen to match our uniform, reference design (using the Reception screen as the baseline).

**Instructions for the generated prompt:**  
- The prompt must direct the user to refactor the target screen using the Reception screen as a reference for layout, structure, and interaction patterns.
- The standardized layout must include:
  - A set of tabs at the top of the page, with the tab definitions depending on the requirements of the specific screen.
  - Each tab must be routable. This means every tab should have its own route (URL), supporting deep linking and nested routing within the app.
  - The primary action button related to the current tab should be positioned on the right side of the tabs row. The button's label and action should update according to the selected tab.
  - The page body must consist solely of the reusable table component (already implemented in the codebase). The table should incorporate:
    - The integrated search bar.
    - The filter button and table settings button.
    - The main table itself, showing the relevant data.
  - The design must strictly follow a mobile-first, fully responsive approach, adapting for mobile, tablet, and desktop screen sizes.
- The generated prompt must explicitly instruct to reuse existing shared components wherever possible, minimizing one-off or duplicate implementations.
- Emphasize the goal: maximize consistency, uniformity, and maintainability of workflow screens by adopting this shared tab-and-table layout.

**Output:**  
- The generated prompt must be saved inside the `prompts/` folder.
- The filename should be derived from the screen name in kebab-case, prefixed with the next available number (e.g., `14-standardize-patient-management.md`).
- The prompt file should be titled "Standardize {screen_name} Screen", applying all the above rules.

**Usage:**  
- Provide only the name of the screen you wish to standardize as the first line of this file (replacing `{screen_name}`).

Example:  
_Input:_ `Patient Management`  
_Output:_ File `prompts/14-standardize-patient-management.md` titled "Standardize Patient Management Screen", applying all the above rules.

Use this generator to ensure all workflow screens are uniform, component-reuse-focused, and easily maintainable across evolving app requirements.
