# Soft-Delete Dependency Flagging & UUID Hygiene

Deep-scan and fix admin facility-structure soft-delete so dependents of a soft-deleted parent are cascade-deleted or visibly flagged, and raw UUIDs never appear in the UI. Follow `prompts/.cursor/prompt.mdc`.

## Context

Trees: **Tenant → Facility → Department → Unit**; **Facility → Ward → Room → Bed** (optional: department on ward, ward on room, room on bed). Shared helper: `backend/src/lib/facility-structure/cascade-soft-delete.js` (delete cascades; restore is parent-only and needs an active parent chain). Gaps: incomplete cascades (e.g. facility), active rows still linking soft-deleted optional parents without a Deleted flag, UUID leakage in list/filter/details, and create options offering soft-deleted parents.

**Flagged:** related name shows Deleted / parent-unavailable (`tenantFacilityStructureDeletedStatus` or equivalent), and mutations needing an active parent are blocked with clear validation—not silent orphans.

## Requirements

1. Map every admin-setup soft-delete path (tenant, facility, department, unit, ward, room, bed) and every FK/consumer in backend + `/admin/setup` UI. Reconcile gaps vs the trees above before fixing.
2. Soft-delete must cascade to hierarchical descendants via shared cascade helpers (extend the lib; no one-off delete paths). Restore stays parent-only (no auto-restore of children) and requires an active parent chain (409 with existing error keys).
3. When a record stays active but references a soft-deleted optional parent, list/details/filters must flag that related name Deleted/unavailable. Exclude those parents from create option lists.
4. After soft-delete or restore, refresh affected lists, counts, and open details so flags stay in sync without empty/gate flash.
5. Never expose raw UUIDs/opaque ids in lists, filters, forms, chips, toasts, empty/error copy, or details. Use display names and `human_friendly_id` only; keep UUIDs internal to API/state.
6. Scan and remove UUID leakage in presentation and DTOs/mappers that surface opaque ids as user-visible text (details, table cells, filter labels, similarity and post-save dialogs).
7. Cover loading, empty, no-results, error/retry, success, validation, and Deleted/parent-unavailable states. Unauthorized soft-delete/restore controls must not render.
8. Extend backend + frontend tests for cascade delete, restore parent-chain rules, dependent flagging, list refresh, and absence of UUID strings in rendered setup UI.

## Constraints

- Reuse cascade-soft-delete, setup helpers, soft-delete/restore chrome, theme tokens, and details dialogs; extend rather than fork.
- Soft delete only from list Delete; no hard delete. Backend RBAC/ABAC authoritative.
- No unrelated work outside soft-delete dependency behavior and UUID hygiene on admin setup.

## Acceptance Criteria

- Cascade map vs code reconciled; hierarchical soft-delete uses shared helpers (Req 1–2).
- Restore does not revive children; blocked when parent chain inactive (Req 2).
- Active rows with soft-deleted optional parents show Deleted/unavailable; those parents absent from create options (Req 3).
- Post delete/restore, lists/counts/details update without flash (Req 4).
- Admin-setup surfaces show no raw UUID/`resourceUuid` as visible text; names + `human_friendly_id` only (Req 5–6).
- UI states and auth absence covered; tests prove cascade, restore rules, flagging, and no UUID leakage (Req 7–8).

## Relevant Files

- `backend/src/lib/facility-structure/cascade-soft-delete.js`
- `backend/src/modules/{tenant,facility,department,unit,ward,room,bed}/`
- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/*_details_dialog.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/tenant_facility_setup_helpers.dart`
- `frontend/test/features/tenant_facility/`
- Structure delete/restore backend tests under `backend/`
