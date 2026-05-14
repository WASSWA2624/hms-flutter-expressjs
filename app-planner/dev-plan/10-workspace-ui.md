# 10 - Workspace UI Pattern

## Goal
Define one reusable UI pattern for all HOSSPI HMS module workspaces.

## Workspace Structure
Each module should use this layout:
1. module header with title, short description, status, and primary action;
2. compact KPI/summary cards where useful;
3. searchable/filterable list or table;
4. detail drawer, side panel, or detail page depending on complexity;
5. modal actions for short create/edit/status workflows;
6. clear empty, loading, error, forbidden, and offline states;
7. audit/activity section where relevant.

## Source Organization
Use a feature-first structure:

```text
frontend/lib/features/<feature>/
  data/
  domain/
  presentation/
```

Do not put product business logic in shared components.

## UX Rules
- Avoid congested screens.
- Prefer one primary action per screen.
- Keep filters compact.
- Keep forms short and grouped.
- Use modal actions for quick work.
- Use full pages for complex clinical, billing, claim, theater, ICU, and discharge workflows.
- Avoid routing users away from a module unless the workflow requires it.

## Done Criteria
- New modules follow the same structure.
- Shared components are reused.
- Tables, filters, modals, details, and state views behave consistently.

## Rule References
### Frontend rules
- `frontend/app-planner/app-rules/feature_workflow.md`
- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
### Backend rules
- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/performance.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.
