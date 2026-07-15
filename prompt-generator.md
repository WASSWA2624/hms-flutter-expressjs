{screen_name}

---

# Screen Standardization Prompt Generator

You are a prompt generator. Given the screen name on the first line of this file, you must produce a comprehensive, context-aware refactoring prompt and save it to the `prompts/` folder.

## Step 1: Codebase Discovery (mandatory before generating)

Before writing any prompt content, perform a full audit of the codebase to gather context specific to the target screen. You must:

### 1.1 Locate the target screen

- Find all files related to `{screen_name}`: pages, widgets, controllers, providers, repositories, models, routes, and tests.
- Identify the current page structure, layout, navigation setup, and state management approach.
- Note which shared components it already uses and which it duplicates or ignores.

### 1.2 Audit the reference implementation (Reception workspace)

- Read `reception_workspace_page.dart` and its supporting files to extract the canonical patterns:
  - Tab structure and how tabs are defined.
  - Routing: how each tab maps to a route segment.
  - Primary action button placement and per-tab behavior.
  - Table usage: `AppListTable` configuration, search bar integration, filter/settings buttons.
  - Mobile/responsive breakpoints and layout switching.
  - State management and data-fetching patterns.

### 1.3 Inventory shared components

- Locate and list all shared/reusable components relevant to the standardization:
  - `AppListTable` (or equivalent data table widget).
  - Tab bar / routable tab components.
  - Search bar widget.
  - Filter and table-settings buttons/dialogs.
  - Primary action button patterns.
  - Responsive layout wrappers/breakpoint utilities.
  - Any `WorkflowActionButton` or workflow infrastructure already wired.

### 1.4 Identify the gap

- Compare the target screen's current implementation against the reference.
- List concrete differences: missing tabs, non-routable navigation, inline tables instead of `AppListTable`, missing search/filter, non-responsive layout, duplicated components, inconsistent state management.

### 1.5 Check route configuration

- Find the target screen's route definition in the app router.
- Determine if it already supports tab-based sub-routes or needs restructuring.
- Note any deep-link query models already defined for this module.

### 1.6 Identify domain-specific requirements

- Determine what data the screen displays (entities, providers, API endpoints).
- Identify the tabs that make sense for this screen based on domain logic (e.g., statuses, categories, workflow stages).
- Identify the primary action per tab (e.g., "New Patient", "Create Order", "Admit").
- Note any screen-specific behaviors that must be preserved during refactoring.

## Step 2: Generate the Prompt

Using the audit findings, generate a detailed, actionable refactoring prompt. The prompt must follow this structure:

### Generated prompt structure

```
# Standardize {screen_name} Screen

## Objective
[One paragraph stating the goal: refactor {screen_name} to match the standardized tab-and-table layout used by the Reception workspace.]

## Current State (from audit)
[Bullet list summarizing what currently exists — files, layout, components used, issues found.]

## Target Architecture

### Tab Configuration
[Table listing each tab: name, route path, description, primary action button label and behavior.]

### Routing
[Exact instructions for making each tab routable with its own URL segment. Reference existing router patterns found in the audit.]

### Page Layout
[Step-by-step layout specification:
- Tab bar with routable tabs
- Primary action button positioned to the right of tabs
- Body: AppListTable with integrated search, filter button, settings button
- Responsive behavior for mobile/tablet/desktop]

### Data & State Management
[Instructions on providers, repositories, controllers to use or create. Reference existing patterns from the audit.]

## Implementation Steps
[Numbered, ordered list of specific file-level changes:
1. Create/modify route definitions
2. Create tab enum/configuration
3. Refactor page widget to use shared tab layout
4. Wire AppListTable with correct columns, data source, search, filters
5. Add primary action button per tab
6. Implement responsive breakpoints
7. Remove old/duplicated components
8. Update tests]

## Shared Components to Use
[Explicit list of shared components (with file paths from the audit) that MUST be reused. No new implementations of these.]

## Files to Modify
[Complete list of files that will be created, modified, or deleted.]

## Files to Reference (do not modify)
[List of reference files the implementer should read for patterns — Reception workspace, shared components, router config.]

## Responsive Design Requirements
- Mobile: [specific layout]
- Tablet: [specific layout]
- Desktop: [specific layout]

## Testing Requirements
- [ ] Tab navigation works and URLs update
- [ ] Deep linking to each tab works
- [ ] Table displays correct data per tab
- [ ] Search filters table content
- [ ] Filter button opens filter dialog
- [ ] Primary action button changes per tab
- [ ] Responsive layout adapts correctly at each breakpoint
- [ ] Existing functionality is preserved

## Acceptance Criteria
[Bullet list of pass/fail conditions for the refactor.]
```

## Step 3: Save the Output

- Determine the next available numeric prefix by inspecting existing files in `prompts/`.
- Save the generated prompt as: `prompts/{NN}-standardize-{screen-name-kebab-case}.md`
  - Example: if `{screen_name}` is "Patient Management" and the highest existing prefix is `13`, save as `prompts/14-standardize-patient-management.md`.

## Rules

1. **Never generate a generic prompt.** Every section must reference actual file paths, component names, provider names, and patterns discovered during the audit.
2. **Do not guess.** If a shared component or pattern cannot be found in the codebase, note its absence and instruct the implementer to create it following the Reception reference.
3. **Preserve domain logic.** The generated prompt must not remove screen-specific business behavior — only restructure the UI layer to match the standard layout.
4. **Reuse over reinvention.** The generated prompt must explicitly forbid creating new table, tab, search, or filter implementations when shared ones exist.
5. **Be specific.** Reference exact file paths, class names, widget names, provider names, and route paths. Vague instructions like "use the shared table" are insufficient — specify which import, which constructor, which parameters.
6. **Mobile-first.** The responsive design section must specify concrete breakpoints and layout changes, not just "make it responsive."

## Usage

Replace `{screen_name}` on line 1 with the name of the screen to standardize, then run this file as a prompt. The generator will audit the codebase and produce a saved, ready-to-execute refactoring prompt in `prompts/`.
