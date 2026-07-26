# Show tenant similarity results in a dedicated dialog — `/admin/setup?section=tenants`

## Objective

Move tenant duplicate-detection feedback out of the create form and into a dedicated results dialog that always reports the comparison outcome before a tenant is created.

## Context

- Tenant creation and multi-field similarity scoring already exist in the tenant profile form, similarity dialog, and backend similarity check.
- Today, "no match" and near-match feedback surface as inline messages inside the form; only some cases open a dialog.
- Reuse the existing similarity entities, scoring, dialog, localization, access policy, and API contract. Do not add a parallel implementation.

## Requirements

1. On every create submission, run the similarity check and open the results dialog before creating, whether the result is no match, near matches, or an exact conflict.
2. In the dialog, show the overall outcome and, per compared parameter, the input value, candidate value, score, and status (match, similar, different, missing).
3. For each candidate, show its identity and aggregate score, ordered strongest first.
4. Keep actions state-appropriate: cancel/return to editing, use an existing tenant, or create anyway; suppress create-anyway for non-overridable exact-slug conflicts.
5. Remove inline similarity/duplicate messages from the form; keep field-level required/format validation inline.

## Constraints

- Reference `.cursor/mandatories.mdc`; do not restate its rules.
- Preserve edit behavior, current visuals, and responsive layout without overflow.

## Acceptance Criteria

- Submitting a create always opens the results dialog with per-parameter scores, matches, and contradictions.
- No similarity message renders inline in the form.
- Exact-slug conflicts cannot be created anyway.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_similarity_dialog.dart`
- `frontend/lib/features/tenant_facility/domain/entities/tenant_similarity.dart`
- `backend/src/lib/tenant/tenant-similarity.js`
- `frontend/lib/l10n/app_en.arb`
