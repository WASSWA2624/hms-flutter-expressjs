# 10 - Workspace UI Pattern

## Goal

Define one reusable UI pattern for all HOSSPI HMS module workspaces so the app looks uniform, stays simple, supports fast hospital work, and avoids redesigning screens from module to module.

## Source of Truth

- Use frontend app-rules for architecture, components, forms, responsive behavior, state management, navigation, permissions, and performance.
- Use `app-write-up.md` for module boundaries.
- Use `opd-flow.md` and `ipd-flow.md` for patient movement and status context.
- Use `01-policy.md` for modal-first actions, role access, print/report rules, and targeted state updates.

## Standard Workspace Structure

Each module should use this layout:

1. module header with title, short plain-language description, status, and one primary action;
2. compact KPI/summary cards only where they help the task;
3. searchable/filterable worklist, list, or table;
4. readable row/card status badges;
5. detail drawer, side panel, or detail page depending on complexity;
6. modal actions for short create/edit/status workflows;
7. clear empty, loading, error, forbidden, offline, validation, and success states;
8. audit/activity section where relevant;
9. generated report/print/export actions where allowed.

## Source Organization

Use a feature-first structure:

```text
frontend/lib/features/<feature>/
  data/
  domain/
  presentation/
```

Do not put product business logic in shared components. Shared components should provide consistent UI behavior only.

## Standard Screen Pattern


| Area           | Requirement                                                                                                     |
| -------------- | --------------------------------------------------------------------------------------------------------------- |
| Header         | Plain title, primary action, optional status chips.                                                             |
| Filters        | Compact, resettable, debounced where remote search is used.                                                     |
| Worklist       | Paginated or lazy list with clear row action and current status.                                                |
| Detail         | Drawer/panel for normal detail, page only for complex review.                                                   |
| Actions        | Open from row, detail panel, or primary action as modals where safe.                                            |
| State          | Loading, empty, error, forbidden, offline, and success states must be consistent.                               |
| Responsiveness | Mobile uses one-column cards; tablet/desktop can use worklist + detail; large desktop uses readable max widths. |


## Modal Action Pattern

Use modals for quick actions so users do not lose their place.


| Action Type   | Modal Behavior                                                               |
| ------------- | ---------------------------------------------------------------------------- |
| Create/edit   | Short form, clear required fields, save/cancel, duplicate-submit protection. |
| Request/order | Search configured catalog, select items, add short notes, submit.            |
| Payment       | Amount due, payment method, reference, receive/confirm, receipt action.      |
| Status update | Current status, allowed next status, reason if needed, confirm.              |
| Print/export  | Choose template/output, preview summary, generate/download/print.            |
| Confirmation  | Clear consequence, cancel as safe default, role-gated submit.                |


Avoid many stacked modals. For nested work, prefer one modal with sections or a small stepper. A confirmation can appear inside the same action flow when necessary. Return the user to the same worklist/detail context after success.

## Patient Context Pattern

Patient-related modules should use a consistent patient context header:

- patient name;
- patient number/MRN;
- age/sex where available;
- allergies and critical alerts;
- current encounter/admission number;
- current OPD/IPD status;
- location/ward/bed when applicable;
- payer/coverage where relevant;
- current responsible provider or department.

## Catalog Selection Pattern

Use configured catalogs for request-heavy tasks:

- lab tests and panels;
- radiology/imaging tests;
- drugs/formulary and batches where relevant;
- billing services and prices;
- payment methods;
- coverage plans;
- departments, units, rooms, wards, and beds;
- providers and staff;
- report templates.

Searchable selects should be fast, debounced, and not push unrelated content down.

## State and Refresh Pattern

- Controllers own presentation state and user actions.
- Repositories own data coordination.
- UI must not call HTTP directly.
- After save, refresh only the affected row, badge, tab, section, provider, queue, notification count, or report preview.
- Use backend response data for final status and timestamps.
- Preserve filters, pagination, selected row, and scroll position after modal actions.

## UX Rules

- Avoid congested screens.
- Prefer one primary action per screen.
- Keep filters compact.
- Keep forms short and grouped.
- Use modal actions for quick work.
- Use full pages for complex clinical, billing, claim, theater, ICU, payroll, and discharge workflows.
- Avoid routing users away from a module unless the workflow requires it.
- Avoid raw API names, technical status codes, and implementation details in the UI.

## Done Criteria

- New modules follow the same workspace structure.
- Shared components are reused.
- Tables, filters, modals, details, report actions, and state views behave consistently.
- Mobile, tablet, desktop, web, and large desktop layouts remain readable.
- Targeted state refresh is used instead of unnecessary whole-screen reloads.

## Rule References

### Product and flow references

- `app-planner/app-write-up.md`
- `app-planner/opd-flow.md`
- `app-planner/ipd-flow.md`
- `app-planner/dev-plan/01-policy.md`
- `app-planner/dev-plan/10-workspace-ui.md`

### Frontend rules

- `frontend/app-planner/app-rules/architecture.md`
- `frontend/app-planner/app-rules/project_structure.md`
- `frontend/app-planner/app-rules/navigation.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/responsive_adaptive_design.md`
- `frontend/app-planner/app-rules/state_management.md`
- `frontend/app-planner/app-rules/network_api.md`
- `frontend/app-planner/app-rules/permissions.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`
- `frontend/app-planner/app-rules/localization_i18n.md`
- `frontend/app-planner/app-rules/performance.md`
- `frontend/app-planner/app-rules/accessibility.md`

### Backend rules

- `backend/app-planner/app-rules/api.md`
- `backend/app-planner/app-rules/api-versioning.md`
- `backend/app-planner/app-rules/response-format.md`
- `backend/app-planner/app-rules/auth-security.md`
- `backend/app-planner/app-rules/validation.md`
- `backend/app-planner/app-rules/module-creation.md`

### Additional references

- `frontend/app-planner/app-rules/feature_workflow.md`
- `frontend/app-planner/app-rules/reusable_components.md`
- `frontend/app-planner/app-rules/forms.md`
- `frontend/app-planner/app-rules/search_filtering.md`
- `frontend/app-planner/app-rules/pagination_data_tables.md`

Respect these documents when implementing the step. Do not edit backend or frontend planner files unless a future task explicitly allows it.