# Radiology workspace desk

Refine the radiology module desk so tabs, counts, and chrome match day-to-day imaging work: keep Worklist, repurpose Reporting/Released into clear “today” boards, keep historical All orders and Follow-ups, remove module configuration/view toggles from the tab toolbar, and put Request imaging in the search-bar action cluster with readable Next action labels and trustworthy real-time tab counts.

## Context

- Desk shell: `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart` (`AppTabStrip`, `_buildPrimaryAction`, `_buildSecondaryActions`, `_RadiologyOrderBoard`, section URL `?section=`).
- Parts: `radiology_workspace_page.configurations.dart` (Configurations dialog—must leave the radiology desk), `radiology_workspace_page.detail_cells.dart`, `radiology_workspace_page.print.dart`.
- Sections enum: `RadiologyDeskSection` in `frontend/lib/features/radiology/domain/entities/radiology_entities.dart` — today `worklist | reporting | released | allOrders | followUps`.
- Stage wiring today: Worklist/`ALL`, Reporting/`REPORTING`, Released/`COMPLETED`, All orders/`ALL`, Follow-ups → shared `FollowUpWorklistPanel`.
- Counts: `RadiologyWorkspaceState.workloadCount` / `reportingCount` / `releasedCount` / summary totals; Follow-ups via `followUpTabCountProvider`.
- Access: `frontend/lib/features/radiology/presentation/radiology_access.dart` (per-section strip create / configure / write).
- Next action: `frontend/lib/features/radiology/presentation/widgets/radiology_next_action_cell.dart` (compact `labelSmall` link—too small).
- Search / table chrome: `AppListTable` + `AppSearchBar` on `_RadiologyOrderBoard` (Filters, Export, Settings already in trailing actions).
- Catalog / modality setup already lives under Tenant setup Clinical Services (`facility_catalog_config_panel.dart`); radiology desk must not own configuration.
- Backend board: `backend/src/modules/radiology-workspace/` (worklist payload, summary counts, stage filters).
- Follow `.cursor/locale-development.mdc`, `.cursor/mandatories.mdc`, `frontend/.cursor/ui-feedback.mdc`, and existing `AppTabStrip` / search-bar action patterns.

## Requirements

1. **Keep Worklist:** Leave the Worklist tab as the active acquisition / pending imaging board (current Worklist behavior is the baseline). Do not fold Worklist into All orders.
2. **Repurpose Reporting → Reports today:** Remove the ambiguous “Reporting” product meaning. Rename the tab to a clear **Reports today** label (English l10n) and scope the board to **reports completed / finalized today** (facility-local day boundary consistent with other “today” desks). Update URL section aliases so old `reporting` links still resolve.
3. **Repurpose Released → Procedures completed today:** Rename **Released** to **Procedures completed today** (or equally clear localized equivalent) and scope it to **imaging procedures completed today**, independent of the Reports today list when product semantics differ (report finalized vs procedure performed). Keep old `released` URL aliases.
4. **All orders = historical / all others:** Keep an All orders (or “All others”) tab for procedures **completed in the past** (not today) and any remaining non-today board rows the product still needs discoverable—do not duplicate today’s completed lists. Clarify empty copy so users know this is the historical board, not the live Worklist.
5. **Follow-ups:** Keep Follow-ups as procedures/orders marked for follow-up via the existing shared Follow-ups panel; counts and actions stay on that panel’s contract.
6. **Remove desk toolbar chrome:** Delete the tab-strip **Orders/Patients view** toggle and **Configurations** secondary actions from the radiology desk. Do not open the radiology configurations dialog from this module. Catalog / procedure enablement stays in **Tenant setup → Clinical Services**; remove or gate dead configure entry points so permissions docs match UI.
7. **Request imaging in search bar:** Move **Request imaging** out of `AppTabStrip.primaryAction` into the board `AppSearchBar` trailing actions (same create dialog / permission gate as today). Hide it on Follow-ups (no create chrome there today).
8. **Trailing action order:** On radiology boards, search-bar trailing order must be **Filters → Settings → Export → Request imaging** (then any overflow). Do not leave Request imaging as a separate tab-strip primary that fights this cluster.
9. **Next action readability:** Make the Next action control clearly readable at desktop density—stop using undersized compact `labelSmall` as the default for the primary next-step link. Prefer body/label medium weight, adequate tap target, and still one clear verb (e.g. Confirm billing). Cancelled / non-action rows can stay muted text.
10. **Honest, independent tab counts:** Each tab badge must reflect that section’s real dataset (DB / workspace summary for that scope), not a reused or cross-contaminated counter. Counts update with workspace refresh / realtime sync already used by the module so badges do not lie after mutations. Follow-ups keeps its own provider count.
11. **Export still works:** Keep shared `AppListTable` Export on these boards. Exported `.xlsx` must include populated data cells for selected columns (explicit `exportValue` and/or the shared cell-text fallback)—never headers-only when rows are visible. Action/next-action chrome columns stay out of the file unless explicitly exportable.
12. **l10n + tests:** English strings for new tab labels, empty states, and any count/day copy; widget/controller tests for section scoping (today vs historical), toolbar removal, search-bar action order, next-action typography/visibility, and count independence; URL alias tests for renamed sections.

Optional enhancements: none (do not add a second configuration surface or a new radiology settings page).

## Constraints

- Reuse `AppTabStrip`, `AppListTable`, `AppSearchBar`, Follow-ups panel, existing create-imaging dialog, and radiology access atoms. Do not invent a parallel radiology shell.
- Prefer tightening frontend section filters + summary fields; extend `radiology-workspace` summary/query only as needed for accurate “today” / historical scopes and counts.
- Do not move Tenant setup catalog configuration into this desk; deleting configure from the strip is required, not relocating it here.
- Preserve permission gating for Request imaging / write / billing next actions; removing Configurations must not orphan required setup—admins use Tenant setup.
- No unrelated refactors outside radiology desk tabs, chrome, counts, next-action, export wiring, l10n, and tests.
- Responsive: search-bar trailing actions remain usable on mobile overflow; Next action remains tappable on narrow layouts.

## Acceptance Criteria

- AC1 (Req 1–5): Tabs are Worklist, Reports today, Procedures completed today, All orders (historical), Follow-ups; each board shows the scoped rows described above; old section query values still route.
- AC2 (Req 6–8): No Orders/Patients or Configurations actions on the radiology tab strip; Request imaging lives in the search bar after Filters → Settings → Export.
- AC3 (Req 9): Next action labels are clearly readable and remain the primary row next step.
- AC4 (Req 10–11): Tab counts match each section’s data and stay fresh; Export downloads populated rows for visible data columns.
- AC5 (Req 12): English l10n and tests cover sections, chrome, counts, next action, and export.

## Relevant Files

- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.configurations.dart`
- `frontend/lib/features/radiology/presentation/pages/radiology_workspace_page.detail_cells.dart`
- `frontend/lib/features/radiology/presentation/widgets/radiology_next_action_cell.dart`
- `frontend/lib/features/radiology/presentation/controllers/radiology_workspace_controller.dart`
- `frontend/lib/features/radiology/presentation/radiology_access.dart`
- `frontend/lib/features/radiology/domain/entities/radiology_entities.dart`
- `frontend/lib/features/radiology/data/dtos/radiology_dtos.dart`
- `frontend/lib/shared/follow_up/follow_up_worklist_panel.dart`
- `frontend/lib/shared/components/app_list_table.dart`
- `frontend/lib/shared/components/app_list_table_export.dart`
- `frontend/lib/features/tenant_facility/presentation/widgets/facility_catalog_config_panel.dart`
- `backend/src/modules/radiology-workspace/`
- `frontend/lib/l10n/app_en.arb`
- `.cursor/locale-development.mdc`
- `.cursor/mandatories.mdc`
- `frontend/.cursor/ui-feedback.mdc`
