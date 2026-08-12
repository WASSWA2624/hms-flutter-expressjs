# Clinical inventory — convention gaps

Required compliance gaps vs `prompts/.cursor/*.mdc` after remediation (2026-08-12).

## Residual

None.

## Closed gaps (prompts/07-clinical/99-convention-gaps.md)

| # | Gap | Resolution |
| --- | --- | --- |
| 1 | Route entry ∪ vs catalog ∩ | `AppRoutes.clinical` + `RouteAccessCatalog.clinicalEntry` both ∩ `clinical:read` + `encounters-vitals` |
| 2 | Pending empty `section` / aliases | `_clinicalSectionQueryValue(all)` omits `section`; aliases `pending`/`all` + legacy waiting-review / in-consultation → `all` |
| 3 | `panel` unused | `_applyRouteQuery` opens encounter with `initialPanel`; anchor `clinical_panel_$panel` |
| 4 | Orphan In-consultation / Waiting-review atom maps | Removed; aliases remap to Pending |
| 5 | Completed label vs query | Label `clinicalSectionCompletedLabel` → **Completed**; query `completed` |
| 6 | Pharmacy bulk confirms reused radiology strings | Own ARB keys `clinicalCancelSelectedPharmacyOrders*` / `clinicalDeleteSelectedPharmacyOrders*` |
| 7 | List Export / Print absent | Worklist + Follow-ups Print after Export; ∩ `evidence:export` |
| 8 | Follow-ups Filters off / Reception defaults | Filters + date on; clinical RW override; Reception detail **reused** |
| 9 | Lab/radiology panel read | **Justified exception** — stays ∩ `clinical:read` (matrix nested read n/a) |
| 10 | Write gates | **Justified exception** — source ∪ `clinical:write` \| `platform:admin` |
| 11–14 | Counts / sibling model / tones | Facet totals under shared filter/search; Follow-ups narrowed via `onNarrowedCountChanged`; tones danger/warning/info as inventoried |
| 15–19 | Print/Export/columns/filters | Filters → Settings → Export → Print; 5 defaults (results-ready / completed justified sets); Close on filters |
| 20–22 | Print label + preview | Trigger `Print`; `printClinicalWorkspaceList` / `_printClinicalFollowUpsList` → shared preview |
| 23–24 | Dialogs / in-desk | Clinical encounter shell + reused clinical_actions / Reception follow-up; no nested feature routes |
| 25–26 | Inventory + regression tests | This file + `frontend/test/features/clinical/` |

### Justified product exceptions (tested / documented in code)

1. **Lab/radiology results panel read** stays ∩ `clinical:read` (matrix nested cross-module read _(n/a)_; not separate `lab:read` / `radiology:read`) — see `ClinicalResultsReadyAtomPermissions.labResultsPanel` / `radiologyResultsPanel`.
2. **Write gates** keep source ∪ `clinical:write` \| `platform:admin` rather than matrix ∩ write alone — see `clinicalWorkspaceWriteRequirement`.
3. **Results ready default columns** use patient / encounterType / queue / status / nextAction (still 5; provider omitted so type is visible for results review) — `_clinicalDefaultColumnsForSection` + `results-ready tab shows encounter type column by default`.
4. **Completed default columns** use patient / queue / encounterType / status / nextAction (still 5; provider omitted for completed review) — `_clinicalDefaultColumnsForSection` + `Completed tab shows encounter type column by default`.

## Regression coverage (representative)

- Route / aliases: `clinical_entities_test`, `legacy waiting-review deep link…`, deep-link canonicalize tests
- Panel deep-link: `deep link encounterId+panel opens encounter with panel anchor`
- Export/Print omit + toolbar order: `clinical_workspace_page_test`, follow-ups permissions
- Facet / filtered badges: `clinical_workspace_controller_test`
- Tones / default columns: per-tab page tests
- Follow-ups Filters/Close / narrowed count: `clinical_follow_ups_permissions_test`
