# Discharge inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory (code-traced; no UI changes in this pass).

## Residual

1. **Export ungated** — default AppListTable Export without ∩ `evidence:export`.
2. **No table Print** — no preview-first registry list print.
3. **No strip Plan/Clearance** — only row next-action (tests assert no Refresh/Start strip tooltips).
4. **Empty unauthorized workspace** — `SizedBox.shrink()` vs Reception forbidden view.
5. **Route gate drift** — `AppRoutes.discharge` any-of clinical/pharmacy/billing/operations vs catalog ∩ `discharge:read`.
6. **Tab count authority** — counts from loaded `queue.items` / client filters, not dedicated unfiltered sibling totals.
7. **Follow-ups Filters/date off** — host does not enable advanced filters (Reception Follow-ups has them).
8. **Follow-ups label** — strip uses `opdFollowUpsTitle`, not a discharge-specific section key.
9. **Date filter off** on all discharge queue tabs.
10. **Planning write atoms** hard-coded to `DischargeAllPatientsAtomPermissions.create|update` even when opened from Planned/Pending.
11. **`DischargeClearanceDialog`** unused by workspace page path (planning entry used instead).
12. **Legacy billing dialog keys** unused; Open billing is navigate-only.
