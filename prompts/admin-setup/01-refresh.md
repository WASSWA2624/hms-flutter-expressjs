# Remove Manual Refresh From Admin Setup

Eliminate every manual **Refresh** action on `/admin/setup` so data stays current through automatic sync only. Follow `prompts/.cursor/prompt.mdc`.

## Context

Workspace chrome exposes **Refresh** via `appWorkspaceToolbarWithLabels` (`onRefresh` → setup `refresh()`). Realtime and post-mutation reloads already sync; the manual control is redundant.

## Requirements

1. Remove workspace toolbar **Refresh** on `/admin/setup` (omit `onRefresh`; no labeled or icon-only refresh in page chrome).
2. Scan desk tabs, HR-only body, and reachable dialogs; remove any other manual **Refresh**. Keep **Try again** on retryable failures.
3. Keep automatic sync: realtime refresh, post-mutation reloads, and programmatic `refresh()` across setup surfaces.
4. Preserve selected tab, search, filters, sorting, column settings, scroll, authorization, and layout across automatic reloads.
5. Leave Clinical service catalog and mutation/row actions unchanged.
6. Support loading, empty, error, success, and permission states; do not clear usable rows solely because an automatic refresh is in flight.

## Constraints

- Reuse setup/access-admin controllers, realtime refresh, localization, and design-system chrome.
- Do not change contracts, soft-delete rules, or other screens that still use workspace **Refresh**.
- Do not remove **Try again** or silent `refresh()` used by realtime/mutation sync.

## Acceptance Criteria

- R1–R2: No manual **Refresh** reachable from `/admin/setup`; **Try again** remains where retryable.
- R3–R6: Auto-sync still updates data; view state and other actions survive; loading does not wipe usable content.
- Update setup tests for absent toolbar refresh and intact auto-sync; run Flutter analysis; spot-check light/dark viewports.

## Relevant Files

- `frontend/lib/features/tenant_facility/presentation/pages/tenant_facility_setup_page.dart`
- `frontend/lib/features/tenant_facility/presentation/controllers/tenant_facility_setup_controller.dart`
- `frontend/lib/shared/layout/app_workspace_toolbar.dart`
- `frontend/test/features/tenant_facility/`
- `screens/admin-setup.md`
