# Expand Reception Filters and Table Settings

Make Reception filters and columns section-specific. Follow `prompts/.cursor/prompt.mdc`.

## Context

Filters and settings are incomplete.

## Requirements

1. Configure Appointments, Desk queue, Active visits, and Payment gate independently using authorized data.
2. Search all available fields by default. Let users scope search to patient name/ID/phone, record IDs, staff, reason, status/stage, service, or invoice data when present.
3. Add applicable multi-value filters for status/stage/action, staff/provider, payment/clearance, service/source, demographics, and inclusive scheduled/queued/started date ranges.
4. Combine filter groups with AND and selections within a group with OR. Apply only through **Apply filters**. **Clear filters** resets pending and applied values; invalid ranges show validation.
5. Show active-filter count and isolate state by section. Filtered-empty results use the empty state.
6. List every applicable column in **Table settings**. Keep required columns checked and disabled; persist optional visibility per section; reset section defaults.
7. Keep title-bar close and add localized **Close** as each dialog footer’s rightmost action. Closing discards pending changes.

## Constraints

- Extend shared components for reusable behavior without regressions.
- Reuse contracts, localization, authorization, theme tokens, and dialogs; never expose unavailable or unauthorized data.
- Preserve sorting, accessibility, responsive themes, and loading, error, success, and empty states.

## Acceptance Criteria

- R1–R5: Every section offers combinable filters and scoped search.
- R6–R7: Columns persist independently; reset and non-applying close work.
- Test logic, dates, isolation, columns, authorization, semantics, themes, and viewports; run Flutter analysis.

## Relevant Files

- `frontend/lib/features/reception/presentation/pages/reception_workspace_page.dart`
- `frontend/lib/shared/components/app_search_bar.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/test/features/reception/`
