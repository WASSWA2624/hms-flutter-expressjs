# Fix `/admin/setup` Performance Bottlenecks

Eliminate over-fetching, double loads, missing pagination, and broad rebuilds on `/admin/setup` so each tab loads only what it needs. Follow `prompts/.cursor/prompt.mdc`.

## Context

Tabs: tenants, facility, departments, units, wards, rooms, beds, roles, permissions, users, clinical catalog. Page gates on `loadSetup` (workspace snapshot of structure lists, limit 100, `includeDeleted: true`). Structure tabs then `_reload` another max page; search/status filter client-side; no `AppPage` paging (unlike tenants/facilities/users). Mutations and access `onMutated` call `_refreshSetup`. Tab switch remounts and re-fetches. Create flows load full peers for client Levenshtein similarity. Catalog `_warmAllTabs` prefetches siblings.

**Section-scoped load:** active entity list (+ minimal lookups) with server `page`/`limit`/`search` and deleted filters mapped to API—not a full structure snapshot.

## Requirements

1. Stop blocking any tab on a full structure snapshot. Bootstrap only session/tenant/facility context for chrome/counts; load entity data per active section.
2. Departments/units/wards/rooms/beds: server pagination via `AppListTable`/`AppPageRequest` (default ≤25, not `maxPageSize`), debounced server `search`, and map status/deleted to API. Do not fetch deleted when viewing active-only.
3. Remove double-fetch: drop snapshot lists for structure tabs, or reuse them without a second max-page list plus redundant lookups when names are on the entity DTO.
4. After structure mutations, refresh only the active section list and lightweight counts—no full `loadSetup`. Users/roles/permissions/catalog must not trigger structure snapshot reload.
5. Cache or keep-alive section list state across tab switches so revisit does not remount-and-refetch unless stale/forced.
6. Similarity: use backend `confirm_similar` or a bounded server candidate API—no full peer list + client Levenshtein. Parallelize/reuse cached form scope options.
7. Clinical catalog: load active sub-tab only; remove `_warmAllTabs`/sibling prefetch on entry.
8. Narrow Riverpod watches (`select`) so snapshot/submission flags do not rebuild the desk. Unauthorized controls must not render. Cover loading, empty, no-results, error/retry, success, validation without empty/gate flash.
9. Access-admin: keep lean paginated lists; stop unbounded page-walks for role permissions/user roles on open; lazy/paginated lookups.
10. Prove: non-structure entry skips structure setup lists; structure tabs page/search server-side; mutations skip unrelated sections; warm tab revisit does not duplicate network.

## Constraints

- Reuse `AppListTable`, `AppPageRequest`, list/search APIs, soft-delete chrome, theme tokens, and tenants/facilities paging; extend rather than fork.
- Backend RBAC/ABAC authoritative. Performance only—no unrelated features.
- Do not silently truncate as “all”; UI must page beyond any remaining limit.

## Acceptance Criteria

- Non-structure tabs do not load departments/units/wards/rooms/beds snapshot lists (Req 1, 10).
- Structure tabs default ≤25 with server search and API deleted/active filters (Req 2–3).
- Mutations refresh only affected section/counts; access/catalog skip structure snapshot (Req 4).
- Warm tab revisit does not duplicate fetch (Req 5).
- Similarity/forms avoid full peer Levenshtein; catalog loads one sub-tab (Req 6–7).
- Rebuild scope reduced; unauthorized UI absent; UI states covered (Req 8–9).
- Tests or network checks prove Req 10.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/features/tenant_facility/data/repositories/tenant_facility_repository_impl.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `frontend/lib/features/access_admin/presentation/widgets/access_admin_management_dialogs.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `backend/src/modules/tenant-facility-workspace/`
- `backend/src/modules/{department,unit,ward,room,bed}/`
- `frontend/test/features/tenant_facility/`
