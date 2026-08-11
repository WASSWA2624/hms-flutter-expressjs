# Admin setup inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after code-traced inventory (2026-08-11).

## Residual

1. **No tab counts / tones** on `AppTabStrip`.
2. **No feature `*_access.dart` / `AccessRequirement` atoms** for Setup desk; gates are imperative `AppAccessPolicy` methods; catalog entry is ∩ `setup:read` + facility context while UI uses admin/`hr:write`/`isElevated`.
3. **Export** mostly **ungated** (`AppListTable.enableExport` default true) — Reception uses ∩ `evidence:export`.
4. **No table Print / preview-first** path on Setup desks.
5. Filter label inconsistency: `commonFilterActionLabel` vs `commonFiltersActionLabel`.
6. **Wizard widget unused** by desk; still in tree (`tenant_facility_setup_wizard.dart`).
7. **Deep-link** only `section`/`tab` — no search/action query sync.
8. Roles/Users/Permissions tab visibility includes **`hr:write`** without matching AccessRequirement documentation used by Access Admin workspace.
9. Clinical nested tabs **not** URL-synced.
10. Departments/beds empty-error UX less consistent than units/rooms (plain text vs `AppWorkspaceStatePanel.error`).
11. Platform subscription tabs use **`isElevated`** (role), not `AccessRequirement(all: platform:admin)` like access-admin registrations docs.
