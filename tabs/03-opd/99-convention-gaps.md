# OPD inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code.

## Residual

1. **Table Print absent** (`tables.mdc` / `printing.mdc`) — board tabs Export without preview-first Print after Export.
2. **All-tab count authority** (`tabs.mdc`) — All badge uses client `allItems.length`, not server/`totalItemCount` authoritative total.
3. **Follow-ups Filters omitted** (`tabs.mdc` / `tables.mdc`) — `FollowUpWorklistPanel` hosted with `showAdvancedFilterButton: false` (no Filters / date filter), unlike remediated Reception Follow-ups.
4. **Export RBAC** (`tables.mdc`) — Export mounts with board tables; no explicit ∩ `evidence:export` atom in `opd_access.dart`.
5. **Empty unauthorized workspace** — when no board tabs pass, page returns `SizedBox.shrink()` rather than an explicit forbidden empty state (route catalog may still block entry).

Per-tab inventory lives under this folder; remediation is out of scope for this inventory pass.
