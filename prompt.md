# Feature: Refine Choose Imaging Study catalog dialog (radiology request flow)

## Goal

Polish the **Choose imaging study** picker (`ClinicalRadiologyRequestCatalogDialog`) so filter fields, table data, scrolling, and selection behavior are correct and consistent. Confirmed studies must appear immediately in the parent **Request radiology** dialog.

## Context

Flow: **Request radiology** → **Add study** → **Choose imaging study** → **Confirm selected studies** → back to **Request radiology** with studies listed.

**Primary files:**

- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_request_catalog_dialog.dart`
- `frontend/lib/shared/clinical_actions/dialogs/clinical_radiology_order_action_dialog.dart`
- `frontend/lib/shared/clinical_actions/clinical_radiology_catalog_helpers.dart`
- `frontend/test/shared/clinical_actions/clinical_radiology_order_action_dialog_test.dart` (extend if needed)

## Current state (keep)

Do not regress:

- **Modality** options reflect facility catalog offerings (screenshot confirms this works).
- **Row select / deselect** via checkbox and header tri-state checkbox (user reports this works).
- Search bar, **Radiology filters**, and **Table settings**.
- Catalog loads from `ClinicalCatalogSource.facility` (up to 100 options).
- Parent dialog **Add study**, **Review billing**, and **Request radiology** actions.

## Problems (from screenshots)

| Area | Observed | Expected |
|------|----------|----------|
| **Body region filter** | Dropdown and chip show **"Facility"** with a body/person icon | Anatomical body regions from catalog metadata (e.g. Pelvis, Abdomen)—never catalog source labels |
| **Body region column** | Table shows **"FACILITY"** for studies (e.g. Transvaginal Pelvic Ultrasound) | Real `body_region` / `bodyRegion` metadata, or empty/unknown—not `FACILITY` |
| **Facility UI** | Confusing duplicate/misplaced Facility control near body region | No stray Facility selector in this dialog; catalog source is fixed to facility offerings |
| **Scrolling** | Form + table layout feels cramped; scroll behavior unclear | Entire dialog body scrolls; table scrolls internally only when row count warrants it (~100 rows) |
| **Footer** | **Cancel** button duplicates the dialog **Close (X)** | Remove Cancel; Close dismisses without saving |
| **Selection order** | Selected row stays at original position (e.g. row 50) | Selected studies move to the **top** of the table (most recently selected first among selected rows) |
| **Confirm handoff** | (Verify) studies appear in parent after confirm | **Confirm selected studies** returns selections; parent **Request radiology** list updates immediately |

**Likely root cause (body region):** `clinicalRadiologyOptionBodyRegion` in `clinical_radiology_catalog_helpers.dart` falls back to `clinicalRadiologySecondaryFragment`, which surfaces catalog-source text (`FACILITY`) when `body_region` metadata is missing. Exclude non-anatomical tokens (e.g. `FACILITY`, `GLOBAL`, `FAVORITES`) from body-region resolution and options.

## Filter field requirements

Confirm and fix as needed:

| Field | Source | Notes |
|-------|--------|-------|
| **Modality** | Distinct modalities in facility catalog | Already working—keep |
| **Laterality** | Standard enum + values present in catalog when filtered | Verify options narrow with modality/body region |
| **Priority** | ROUTINE / URGENT / STAT | Verify filter applies to catalog rows |
| **Body region** | `metadata.body_region` or `metadata.bodyRegion` only | Hide field when no valid regions; never show catalog-source labels |
| **Clinical note** | Free text, applied to confirmed selections | Keep |

## Scrolling behavior

1. **Dialog body:** Wrap filter fields + selection count + table chrome in a single scrollable region so short viewports can reach all controls.
2. **Table body:** `AppListTable` keeps its own vertical scroll. The table area should **not** steal scroll until the user is scrolling within a tall result set (design for up to `_maxVisibleCatalogOptions` = 100 rows).
3. Avoid nested scroll conflicts: outer dialog scroll for the form/header; inner scroll only for the table rows.

## Selection and confirm behavior

1. **Sort on select:** Use / extend `orderClinicalRadiologyRequestCatalogItems` so checked rows float to the top; newly selected row becomes first among selected items.
2. **Confirm:** `Navigator.pop(_confirmedSelections())` must merge modality, laterality, priority, body region, and clinical note into each `ClinicalRadiologyCatalogSelection`.
3. **Parent update:** `_openCatalogPicker` in `clinical_radiology_order_action_dialog.dart` must replace `_requests` and `setState` so studies render immediately without closing the parent dialog.

## UI cleanup

- Remove footer **Cancel** (`AppButton.tertiary` with `commonCancelActionLabel`); retain **Confirm selected studies** only.
- Remove or fix any Facility chip/control that is not a body region.
- When body region metadata is absent for all visible catalog items, hide the body region dropdown and chip picker (do not show a misleading placeholder).

## Implementation rules

- Reuse `AppDialog`, `AppListTable`, `AppSelectField`, and existing clinical catalog helpers—no new visual language.
- Fix data mapping in helpers first; avoid hard-coding display overrides in the dialog.
- Add/adjust l10n keys in `frontend/lib/l10n/app_en.arb` only if new labels are needed.
- If backend catalog rows lack `body_region`, document whether the API should be fixed vs. client-only exclusion of bad fallbacks.

## Acceptance criteria

- [ ] Body region filter and table column show anatomical regions only—never **Facility** / **FACILITY**.
- [ ] No duplicate or misplaced Facility control in the Choose imaging study dialog.
- [ ] Modality, laterality, and priority filters reflect facility catalog and correctly narrow results.
- [ ] Entire dialog content is reachable on small viewports; table scrolls independently for large result sets (up to 100 rows).
- [ ] Footer has **Confirm selected studies** only; Close (X) dismisses without saving.
- [ ] Selecting a study moves it to the top of the table; deselecting returns it to the unselected section.
- [ ] Confirm adds/updates studies in the parent **Request radiology** dialog immediately.
- [ ] Existing checkbox selection behavior and facility-scoped catalog loading are unchanged.
