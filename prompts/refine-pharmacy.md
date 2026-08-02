# Pharmacy Tables & Chrome: Actions Headers, Generic Naming, Pinned H-Scroll, Overflow Dot, Export Icon

**Objective:** Align pharmacy `AppListTable` chrome and shared table/tab components with the current Catalog and stock UI so every pharmacy table shows an **Actions** column header, standardizes drug naming to **Generic name**, pins the horizontal scrollbar to the visible viewport bottom, surfaces an attention indicator on the desk-strip **More tabs** overflow control when hidden tabs have non-zero counts, and points the Export affordance icon upward — without changing dispensing, billing, catalog CRUD, RBAC, or desk-section routing unless a requirement below says so.

## Context

Catalog and stock is already an inline desk section (`?section=catalog`) with nested tabs **Drugs / Formulary / Inventory / Room / Shelves** (`PharmacyCatalogPanel`, `PharmacyCatalogTab`). Screenshots of the live UI show:

- **Drugs** columns include Brand name and **Generic (scientific) name**; Formulary uses **Drug name**. Actions cells (Edit / Delete) render with an **empty** header (`label: ''` on `id: 'actions'`).
- **Inventory**, **Room**, and **Shelves** likewise use blank actions headers while row buttons (Adjust/Clear, Create/Edit/Delete, Edit/Delete) are visible.
- Wide catalog tables already scroll horizontally via `AppListTable` / `_DesktopListTable`, but the horizontal scrollbar often sits at the **bottom of the full table content** (below the fold) instead of staying pinned to the **bottom of the visible table viewport**.
- The desk `AppTabStrip` overflow control (`_AppTabOverflowRow`, `Icons.more_vert`, semantic “More tabs”) lists stock-alert / secondary sections (e.g. All orders with count **2**). There is **no** badge/dot on the More button when overflow entries need attention.
- Table Export in the search trailing cluster uses `AppActionIcons.download` (downward arrow). Product intent is an **upward** export/upload glyph.
- Some columns still feel cramped or clipped at desktop widths even when horizontal scroll exists; the shared table should keep columns readable while scrolling.

Relevant code today:

| Area | Location | Current behavior |
| --- | --- | --- |
| Catalog action columns | `pharmacy_catalog_panel.dart` (Drugs ~L344, Formulary ~L639, Inventory ~L1189, Room ~L1746, Shelves ~L1935) | `id: 'actions'`, `label: ''` |
| Naming l10n | `app_en.arb` | `pharmacyDrugGenericNameLabel` = “Generic (scientific) name”; `pharmacyDrugNameLabel` = “Drug name” |
| H-scroll | `app_list_table.dart` `_DesktopListTable` (~L2894–L3151) | Nested horizontal/vertical `Scrollbar`s; not reliably viewport-pinned |
| More tabs | `app_tab_strip.dart` `_AppTabOverflowRow` (~L205–L253) | Overflow menu only; no attention indicator |
| Export icon | `app_list_table.dart` `_searchActions` (~L2055–L2060); `AppActionIcons.download` | Downward download icon |

Order-queue tables already use labeled next-action / Actions strings in places (`pharmacyLineActionsColumnLabel`, `pharmacyNextActionColumnLabel`). Prefer reuse; do not invent parallel naming systems.

## Requirements

1. **Label every pharmacy Actions column.** On all pharmacy module tables that render row action chrome (Catalog nested tabs: Drugs, Formulary, Inventory, Room, Shelves; and any other pharmacy workspace `AppListTable` whose actions column currently uses `label: ''`), set the column header to **Actions** via the existing l10n key `pharmacyLineActionsColumnLabel` (or a shared `commonActionsColumnLabel` if one is introduced and wired consistently). Keep `id: 'actions'` (or existing action ids) so export exclusion and Settings behavior stay correct. Do not change the row buttons themselves (Edit / Delete / Adjust / Clear / Create-shelf).

2. **Standardize drug naming copy to “Generic name”.** Update user-visible pharmacy strings so:
   - `pharmacyDrugGenericNameLabel` reads **Generic name** (replace “Generic (scientific) name”).
   - Formulary (and any pharmacy table/dialog that still shows **Drug name** for the scientific/generic identity) uses **Generic name** instead of “Drug name” where that column/field means the generic identity — reuse `pharmacyDrugGenericNameLabel` or retarget `pharmacyDrugNameLabel` carefully so filters, Settings, Export headers, search placeholders, and edit-dialog labels stay consistent.
   - Keep **Brand name** unchanged. Do not rename backend fields (`genericName`, `brandName`, legacy `name`) or break `displayTitle` / `genericSubtitle` fallbacks.

3. **Pin the horizontal scrollbar to the visible viewport bottom (shared `AppListTable`).** In `_DesktopListTable` / `AppListTable`, ensure that when the table is wider than its viewport the **horizontal scrollbar remains visible at the bottom of the on-screen table area** (above any table footer/pagination if present), not only after scrolling to the end of a tall body. Prefer fixing the shared component so **every** `AppListTable` (pharmacy and elsewhere) inherits the behavior. Preserve vertical scrolling, sticky/header behavior, column resize, and go-to-top. Thumb should remain visible when horizontal overflow exists (`thumbVisibility: true` or equivalent).

4. **Keep all columns nicely readable while scrolling.** As part of the shared table pass, ensure default/min column widths and the table `minWidth` calculation keep headers and cell content legible (no crushed brand/generic/code/form columns; actions column retains enough width for its buttons, including Room’s multi-button row). Horizontal scroll is the overflow strategy — do not hide required always-visible columns. Respect existing column Settings visibility and saved width memory.

5. **Attention indicator on the More tabs overflow control.** In `AppTabStrip`’s overflow More button (`_AppTabOverflowRow` / `tabOverflowMore`), when **any** overflowed tab has a non-null `count` that is **greater than 0**, show a compact attention indicator on the More control (prefer a small red/error-tone **dot** badge on the icon button — theme `colorScheme.error` or equivalent token). When all overflow counts are null or 0, show no indicator. Keep menu items’ existing `(count)` labels. Do not change tab partitioning, selection, or badge tones on visible chips.

6. **Point the Export icon upward.** Change the `AppListTable` search-bar Export trailing action icon from the downward download glyph to an upward export/upload glyph (prefer `AppActionIcons.upload` / `Icons.upload_outlined`, or add a dedicated `AppActionIcons.export` that points up). Keep the visible label **Export** and existing export dialog behavior. Apply consistently wherever the shared table renders that Export control (including pharmacy catalog/order tables). Update related tests that assert `AppActionIcons.download` on Export if present.

7. **Preserve pharmacy behavior outside this polish.** Do not alter nested-tab set, Create/Adjust/Clear/Delete flows, Filters/Settings/Export data contracts, desk `?section=` routing, stock-alert filters, dispensing, billing, MAR, or RBAC gates (`pharmacyCatalogBrowseRequirement` / `pharmacyCatalogWriteRequirement` / section write requirements).

## Constraints

- Prefer shared-component fixes (`app_list_table.dart`, `app_tab_strip.dart`, `app_action_icons.dart`) for scrollbar, column readability, Export icon, and More-tabs indicator so pharmacy inherits them without one-off forks.
- Reuse existing l10n keys where possible; regenerate localizations after `app_en.arb` edits.
- Theme tokens for light and dark; indicator and scrollbars must remain accessible (contrast, semantics on More button reflecting “attention” when the dot is shown).
- No new backend endpoints or Prisma schema changes are expected for this polish.
- Hide unauthorized write actions as today; never render disabled “no access” chrome.

## Acceptance Criteria

- (R1) Drugs, Formulary, Inventory, Room, and Shelves (and any other pharmacy tables that had blank action headers) show an **Actions** column header above the row action buttons.
- (R2) Pharmacy UI copy uses **Generic name** instead of “Generic (scientific) name” and instead of “Drug name” where that field means the generic identity; Brand name unchanged; CRUD still saves brand/generic correctly.
- (R3) On a wide pharmacy (or any) `AppListTable`, the horizontal scrollbar stays visible at the bottom of the **viewport** without scrolling the table body to its end first.
- (R4) With horizontal overflow, all enabled columns remain readable via scroll; actions columns do not clip their buttons at desktop/tablet/mobile supported widths.
- (R5) When the desk strip overflows and at least one overflow tab has `count > 0` (e.g. All orders (2)), the More tabs button shows a red/error-tone attention dot; when all overflow counts are 0/absent, no dot.
- (R6) Export trailing action uses an upward-pointing icon; export still downloads the sheet successfully.
- (R7) Order queues, stock alerts, catalog mutations, and permissions behave as before aside from the UI polish above.

## Verification

- Extend/adjust Dart tests:
  - Pharmacy catalog / workspace tests: Actions header present on nested catalog tables; Generic name string assertions; Export icon glyph.
  - `app_list_table_test.dart` / export tests: upward Export icon; horizontal scrollbar pinned when viewport-bounded (widget/layout assertion or documented manual check if scrollbar geometry is hard to unit-test).
  - `app_tab_strip_test.dart`: More button shows attention indicator iff an overflow tab has `count > 0`; no indicator when all overflow counts are 0.
- Run `flutter analyze` and targeted `flutter test` for pharmacy + shared table/tab suites.
- No backend Jest / schema work expected; if touched incidentally, run the relevant suite.
- Manually verify on `?section=catalog` (all five nested tabs) and a crowded desk strip with overflow (stock-alert tabs in More): Actions headers, Generic name, pinned h-scroll, More-dot, upward Export — light and dark, desktop and narrow widths.

## Relevant Files

- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_catalog_panel.dart` (actions `label: ''` → Actions; Formulary/Drugs naming columns)
- `frontend/lib/features/pharmacy/presentation/pages/pharmacy_workspace_page.dart` (any remaining blank pharmacy action headers)
- `frontend/lib/features/pharmacy/presentation/widgets/pharmacy_drug_edit_dialog.dart` (labels that still say Drug name / Generic (scientific) name)
- `frontend/lib/shared/components/app_list_table.dart` (pinned horizontal scrollbar, column min widths, Export icon)
- `frontend/lib/shared/components/app_list_table_export.dart` (Export dialog icons if they must match the upward glyph)
- `frontend/lib/shared/components/app_tab_strip.dart` (`_AppTabOverflowRow` More-tabs attention indicator)
- `frontend/lib/shared/icons/app_action_icons.dart` (`upload` / optional `export`)
- `frontend/lib/l10n/app_en.arb` (`pharmacyDrugGenericNameLabel`, `pharmacyDrugNameLabel` / Formulary copy; reuse `pharmacyLineActionsColumnLabel`)
- `frontend/test/shared/components/app_list_table_test.dart`, `app_list_table_export_test.dart`, `app_tab_strip_test.dart`
- `frontend/test/features/pharmacy/presentation/**` (catalog/workspace string and header assertions)
