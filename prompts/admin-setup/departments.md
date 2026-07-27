# Departments Tab — Branded Load and Row-Scoped Mutation Feedback

Fix departments loading on `/admin/setup?section=departments`: branded indicator and row-only mutation busy.

## Context

- Inventoried in `screens/admin-setup/departments.md`.
- Initial load uses `CircularProgressIndicator`; post-mutation `_afterMutation` feels like a full-table reload.
- Use `AppLoadingIndicator`; prefer `.compact` for table loads.

## Requirements

1. On initial list load (and non-silent reload with no rows), show `AppLoadingIndicator` instead of `CircularProgressIndicator`; keep error/empty meaning.
2. After Edit save, Delete, Restore, or Permanent delete confirms, show busy only on the affected row; keep other rows visible—no full-list loader.
3. Disable that row’s actions while mutating; clear busy on success or failure; sync the row without a full-table loading flash when rows exist.
4. Create may refresh after success; do not blank a populated table behind a full-list loader.
5. Preserve inventory permissions, dialogs, confirms, and success/validation/failure feedback.

## Constraints

- Reuse `AppLoadingIndicator` and department submission/dialog APIs; extend list/row UI only as needed.
- Do not change form fields, similarity, filters, or other setup tabs.
- No unrelated refactoring.

## Acceptance Criteria

- First load shows branded `AppLoadingIndicator`, not `CircularProgressIndicator` (Req 1).
- Mutation busy is limited to the target row; other rows stay visible (Req 2–3).
- Successful mutation updates/removes that row without a full-table loading flash when rows exist (Req 3–4).
- Create refresh does not full-load a populated table (Req 4).
- Widget tests cover branded initial load and row-scoped busy; `flutter analyze` passes (Req 1–5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/shared/components/app_loading_indicator.dart`
- `frontend/lib/shared/components/app_list_table.dart`
