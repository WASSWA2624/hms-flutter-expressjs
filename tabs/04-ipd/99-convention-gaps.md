# IPD inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code.

## Residual

1. **Table Print absent** (`tables.mdc` / `printing.mdc`) — queue tabs and bed board Export without preview-first Print after Export.
2. **Filters label** (`tables.mdc`) — uses `ipdFiltersLabel` instead of shared `Filters` (`commonFiltersActionLabel`) on queue and bed-board search bars.
3. **Follow-ups Filters omitted** (`tabs.mdc` / `tables.mdc`) — IPD hosts `FollowUpWorklistPanel` with `showAdvancedFilterButton: false` (no Filters / date filter).
4. **Export RBAC** (`tables.mdc`) — Export mounts with `enableExport: true`; no explicit ∩ `evidence:export` atom in `ipd_access.dart`.
5. **Empty unauthorized workspace** — when no tabs pass board read, page returns `SizedBox.shrink()` (route entry may still admit billing-only users who then see no tabs).

Per-tab inventory lives under this folder; remediation is out of scope for this inventory pass.
