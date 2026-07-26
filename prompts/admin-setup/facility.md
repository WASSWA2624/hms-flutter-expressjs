# Facility Create Similarity Review and Scoped Actions

Align facility create duplicate prevention on `/admin/setup?section=facility`.

## Context

- Inventoried in `screens/admin-setup/facility.md`.
- Create uses client name-only `checkFacilityDuplicates`; backend hard-blocks exact name with `assertUniqueFacilityName`.
- Tenant create has multi-field similarity, `similar_exists` / `confirm_similar`, Cancel / Create anyway / Reuse.

## Requirements

1. Scope visibility: platform sees all; tenant actors see permitted tenants’ facilities; facility admins see only their facility, may edit, and must not see Add or delete-lifecycle actions.
2. On create, compare peers under the selected tenant on name, type/status, contacts (phone, email, address), and identifiers; show percent scores with status colors.
3. Always open similarity review on create, including zero matches; offer Cancel, Create anyway when no hard conflict, and Reuse existing.
4. On successful create or reuse, open `_FacilityDetailsDialog`; refresh the list after create.
5. Enforce backend `similar_exists` / `confirm_similar` on create; hard-block exact name conflicts.

## Constraints

- Reuse tenant similarity patterns, dialogs, permissions, and status colors; no new endpoints.
- Do not change tenant-tab behavior.
- No unrelated refactoring.

## Acceptance Criteria

- Facility admins see only their facility, can edit, and never see Add or delete-lifecycle actions (Req 1).
- Similar peers show scored color-coded review; Create anyway saves with `confirm_similar`; Reuse opens details (Req 2–5).
- Zero peers still shows review; exact name conflict blocks proceed (Req 2–3, 5).
- Tests cover similarity, confirm override, review actions, and absent facility-admin actions; analyze passes (Req 1–5).

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_similarity_dialog.dart`
- `backend/src/modules/facility/services/facility.service.js`
