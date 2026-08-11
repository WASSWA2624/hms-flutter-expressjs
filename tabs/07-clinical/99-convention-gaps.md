# Clinical inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after inventory of presentation code (2026-08-11).

## Residual

1. **Route entry mismatch** — `AppRoutes.clinical` ∪ `clinical:read` \| `clinical:write` vs `RouteAccessCatalog.clinicalEntry` ∩ `clinical:read`.
2. **Pending writes empty `section`** — aliases include `pending`/`all` plus remapped legacy waiting-review / in-consultation tabs.
3. **`panel` query unused** after parse (`ClinicalWorkspaceQuery` has it; `_applyRouteQuery` does not open panels).
4. **Orphan atom maps** — `ClinicalInConsultationAtomPermissions`, `ClinicalWaitingReviewAtomPermissions` (+ waiting-review financial inventory) with no live strip sections.
5. **Completed label** uses `clinicalSectionCompletedTodayLabel` while written query value is `completed` (not `completed-today`).
6. **Pharmacy bulk cancel/delete confirm labels** reuse radiology action strings in page wiring.
7. **List Export / Print absent** — print only in encounter action bar (`tables.mdc` / `printing.mdc`).
8. **Follow-ups** reuses Reception dialogs/copy while Clinical RW requirements override; Filters off on host.
9. **Lab/radiology results panel read** stays clinical:read (not separate `lab:read` / `radiology:read`).
10. **Write gates** use source ∪ `clinical:write` \| `platform:admin`, not matrix ∩ write alone.
