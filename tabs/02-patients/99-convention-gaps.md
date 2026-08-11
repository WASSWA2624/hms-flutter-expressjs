# Patients inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code.

## Residual

1. **Table Print absent** (`tables.mdc` / `printing.mdc`) — toolbar has Export but no preview-first Print after Export on any registry tab.
2. **Filters labels** (`tables.mdc`) — uses `patientsAdvancedFiltersAction` / `patientsAdvancedFiltersTitle` instead of shared `Filters` / `Advanced filters` (`commonFiltersActionLabel` / `commonAdvancedFiltersTitle`).
3. **Advanced filters footer** (`tables.mdc` / `dialogs.mdc`) — Clear + Apply only; no **Close** (`commonCloseActionLabel`).
4. **Active-tab filtered counts** (`tabs.mdc`) — strip badges always use overview scope totals; do not switch to filtered membership totals when search/advanced filters narrow the active tab.
5. **Export RBAC** (`tables.mdc`) — Export mounts with the table; no explicit ∩ `evidence:export` atom in `patient_registry_access.dart` (unlike Reception desk export gate).

Per-tab inventory lives under this folder; remediation is out of scope for this inventory pass.
